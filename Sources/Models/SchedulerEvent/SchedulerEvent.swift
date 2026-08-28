//
//  SchedulerEvent.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation
import Logging

struct SchedulerEvent: Codable, Hashable, Identifiable {
    private static let logger: Logger = .init(label: String(describing: Self.self))
    let id: UUID
    var dueDate: Date
    var eventType: SchedulerEventType
    
    init(id: UUID = UUID(), dueDate: Date, eventType: SchedulerEventType) {
        self.id = id
        self.dueDate = dueDate
        self.eventType = eventType
    }
    
    func execute(in context: GuildContext) async throws {
        switch eventType {
        case let .consoleMessage(message):
            try await handleConsoleMessage(message)

        case let .lockWorldSwitching(worldID: worldID):
            guard context.config.foundryFeaturesEnabled else { return }
            try await handleLockWorldSwitching(worldID: worldID, context: context)

        case .unlockWorldSwitching:
            try await handleUnlockWorld(context: context)

        case let .unlockManualWorldSwitching(acquiredAt: acquiredAt):
            try await handleUnlockManualWorld(acquiredAt: acquiredAt)

        case let .sendSessionReminder(bookingID: bookingID):
            try await handleSendSessionReminder(bookingID: bookingID, bookings: context.bookings, config: context.config)

        case let .sendSessionStartsReminder(bookingID: bookingID):
            try await handleSendSessionStartsReminder(bookingID: bookingID, bookings: context.bookings, config: context.config)

        case .removeBooking:
            break

        case let .closeDatePoll(pollID: pollID):
            try await handleCloseDatePoll(pollID: pollID, context: context)

        case let .sendDatePollReminder(pollID: pollID, userID: userID):
            try await handleDatePollReminder(
                pollID: pollID,
                userID: userID,
                datePolls: context.datePolls,
                localization: context.config.localization
            )

        case let .sendOutstandingDatePollReminders(pollID: pollID):
            try await handleOutstandingDatePollReminders(pollID: pollID, context: context)

        case let .repeatDatePoll(pollID: pollID):
            try await handleRepeatDatePoll(pollID: pollID, context: context)

        case let .syncDatePollMessage(pollID: pollID):
            try await handleSyncDatePollMessage(pollID: pollID, context: context)

        case let .publishDatePoll(pollID: pollID):
            try await handlePublishDatePoll(pollID: pollID, context: context)
        }
    }
}

// MARK: - Date Polls
extension SchedulerEvent {
    private func handlePublishDatePoll(pollID: String, context: GuildContext) async throws {
        guard let poll = await context.datePolls.pollForPublication(pollID: pollID, eventID: id) else { return }
        try await DatePollPublisher.publish(
            poll: poll,
            datePolls: context.datePolls,
            client: bot.client
        )
    }

    private func handleCloseDatePoll(pollID: String, context: GuildContext) async throws {
        guard try await context.datePolls.closePoll(id: pollID, eventID: id) != nil else { return }
        try await DatePollMessageSynchronizer.synchronizeLatest(
            pollID: pollID,
            datePolls: context.datePolls,
            client: bot.client
        )
        await context.datePolls.markCloseMessageSynced(pollID: pollID, eventID: id)
    }

    private func handleSyncDatePollMessage(pollID: String, context: GuildContext) async throws {
        try await DatePollMessageSynchronizer.synchronize(
            pollID: pollID,
            eventID: id,
            datePolls: context.datePolls,
            client: bot.client
        )
    }

    private func handleDatePollReminder(
        pollID: String,
        userID: UserSnowflake,
        datePolls: DatePollsService,
        localization: LocalizationContext
    ) async throws {
        guard let poll = try await datePolls.reminderPoll(pollID: pollID, userID: userID) else { return }
        guard let messageID = poll.messageID else { return }
        let pollLink = "https://discord.com/channels/\(poll.guildID.rawValue)/\(poll.channelID.rawValue)/\(messageID.rawValue)"
        let linkLabel = localization.string("date_poll_reminder.link_label", table: "Notifications")
        let payload = Payloads.CreateMessage(
            content: localization.string(
                "date_poll_reminder.content",
                table: "Notifications",
                DiscordUtils.mention(id: userID),
                linkLabel,
                pollLink
            ),
            components: DatePollRenderer.reminderComponents(for: poll, localization: localization)
        )

        do {
            let channel = try await bot.client.createDm(payload: .init(recipient_id: userID)).decode()
            try await bot.client.createMessage(channelId: channel.id, payload: payload).guardSuccess()
        } catch {
            try await bot.client.createMessage(channelId: poll.channelID, payload: payload).guardSuccess()
        }
        await datePolls.markReminderDelivered(pollID: pollID, userID: userID)
    }

    private func handleOutstandingDatePollReminders(pollID: String, context: GuildContext) async throws {
        let source = try await context.datePolls.poll(id: pollID)
        let voterIDs = try await DatePollMemberResolver.voterIDs(
            for: source.campaignRoleID,
            guildID: source.guildID,
            client: bot.client
        )
        let optedOutUserIDs = await context.datePollReminderPreferences.optedOutUsers()
        guard let reminder = try await context.datePolls.automaticReminderRecipients(
            pollID: pollID,
            eventID: id,
            currentVoterIDs: voterIDs,
            optedOutUserIDs: optedOutUserIDs
        ) else {
            return
        }
        guard let messageID = reminder.poll.messageID else {
            await context.datePolls.completeAutomaticReminder(pollID: pollID, eventID: id)
            return
        }

        var firstError: Error?
        for userID in reminder.recipientIDs {
            if await context.datePollReminderPreferences.optedOutUsers().contains(userID) {
                continue
            }
            let pollLink = "https://discord.com/channels/\(reminder.poll.guildID.rawValue)/\(reminder.poll.channelID.rawValue)/\(messageID.rawValue)"
            let localization = context.config.localization
            let content = localization.string(
                "date_poll_reminder.content",
                table: "Notifications",
                DiscordUtils.mention(id: userID),
                localization.string("date_poll_reminder.link_label", table: "Notifications"),
                pollLink
            )
            do {
                let channel = try await bot.client.createDm(payload: .init(recipient_id: userID)).decode()
                try await bot.client.createMessage(
                    channelId: channel.id,
                    payload: .init(
                        content: content,
                        components: DatePollRenderer.automaticReminderComponents(
                            for: reminder.poll,
                            localization: context.config.localization
                        )
                    )
                ).guardSuccess()
                await context.datePolls.markAutomaticReminderDelivered(pollID: pollID, eventID: id, userID: userID)
            } catch {
                do {
                    try await bot.client.createMessage(
                        channelId: reminder.poll.channelID,
                        payload: .init(
                            content: content,
                            components: DatePollRenderer.automaticReminderComponents(
                                for: reminder.poll,
                                localization: context.config.localization
                            )
                        )
                    ).guardSuccess()
                    await context.datePolls.markAutomaticReminderDelivered(pollID: pollID, eventID: id, userID: userID)
                } catch {
                    firstError = firstError ?? error
                }
            }
        }
        if let firstError {
            throw firstError
        }
        await context.datePolls.completeAutomaticReminder(pollID: pollID, eventID: id)
    }

    private func handleRepeatDatePoll(pollID: String, context: GuildContext) async throws {
        guard let source = await context.datePolls.repeatPollSource(pollID: pollID, eventID: id) else { return }
        let voterIDs = try await DatePollMemberResolver.voterIDs(
            for: source.campaignRoleID,
            guildID: source.guildID,
            client: bot.client
        )
        guard let poll = await context.datePolls.createRepeatingPoll(
            sourceID: pollID,
            eventID: id,
            scheduledDate: dueDate,
            requiredVoterIDs: voterIDs
        ) else {
            return
        }

        try await DatePollPublisher.publish(
            poll: poll,
            datePolls: context.datePolls,
            client: bot.client
        )
    }
}

// MARK: - Console Message
extension SchedulerEvent {
    private func handleConsoleMessage(_ message: String) async throws {
        Self.logger.info("\(message)")
    }
}

// MARK: - Lock World
extension SchedulerEvent {
    private func handleLockWorldSwitching(worldID: String, context: GuildContext) async throws {
        Self.logger.debug("Locking world '\(worldID)'")
        try await context.bookings.startWorldSwitching(eventID: id, worldID: worldID)
        await presenceService.refresh(forceWorldRefresh: true)
        let updatedPolls = await context.datePolls.reconcileBookingLinks(bookings: await context.bookings.allBookings)
        await DatePollMessageSynchronizer.synchronize(
            updatedPolls,
            datePolls: context.datePolls,
            client: bot.client
        )
    }
}

// MARK: - Unlock World
extension SchedulerEvent {
    private func handleUnlockWorld(context: GuildContext) async throws {
        guard let booking = await context.bookings.booking(associatedEventID: id) else {
            Self.logger.warning("Skipping unlock event \(id): no active booking owns it.")
            return
        }

        let unlocked = try WorldLockService.shared.unlockWorldSwitching(
            guildID: context.guildID,
            bookingID: booking.id
        )
        if !unlocked {
            Self.logger.debug("Skipping unlock event \(id): current lock has a different owner.")
        }
        await presenceService.refresh()
    }

    private func handleUnlockManualWorld(acquiredAt: Date) async throws {
        _ = try WorldLockService.shared.unlockManualWorldSwitching(acquiredAt: acquiredAt)
        await presenceService.refresh()
    }
}

// MARK: - Send Session Reminder
extension SchedulerEvent {
    private func handleSendSessionReminder(
        bookingID: UUID,
        bookings: BookingsService,
        config: GuildConfig
    ) async throws {
        guard let booking = await bookings.booking(id: bookingID) as? EventBooking else {
            Self.logger.error("Booking with ID \(bookingID) not found.")
            return
        }
        
        Self.logger.debug("Sending session reminder for session at \(booking.date)")
        guard let reminderChannel = config.reminderChannel else {
            Self.logger.warning("There is no reminder channel set up in which to send the message.")
            return
        }
        
        // Send a reminder to the role with the given snowflake
        try await bot.client.createMessage(
            channelId: reminderChannel,
            payload: .init(
                content: config.localization.string(
                    "session_reminder.content",
                    table: "Notifications",
                    DiscordUtils.mention(id: booking.campaignRoleSnowflake),
                    DiscordUtils.timestamp(date: booking.date)
                ),
                embeds: [Utils.createBookingEmbed(for: booking, localization: config.localization)]
            )
        ).guardSuccess()
    }
}

// MARK: - Send Session Starts Reminder
extension SchedulerEvent {
    private func handleSendSessionStartsReminder(
        bookingID: UUID,
        bookings: BookingsService,
        config: GuildConfig
    ) async throws {
        guard let booking = await bookings.booking(id: bookingID) as? EventBooking else {
            Self.logger.error("Booking with ID \(bookingID) not found.")
            return
        }
        
        Self.logger.debug("Sending session starts reminder for session at \(booking.date)")
        guard let reminderChannel = config.reminderChannel else {
            Self.logger.warning("There is no reminder channel set up in which to send the message.")
            return
        }
        
        let durationString = Utils.durationString(
            for: config.sessionStartReminderTime,
            unitStyle: .long,
            localization: config.localization
        )
        let content: String
        if let location = booking.location {
            content = config.localization.string(
                "session_start.content_with_location",
                table: "Notifications",
                DiscordUtils.mention(id: booking.campaignRoleSnowflake),
                durationString,
                DiscordUtils.mention(id: location)
            )
        } else {
            content = config.localization.string(
                "session_start.content",
                table: "Notifications",
                DiscordUtils.mention(id: booking.campaignRoleSnowflake),
                durationString
            )
        }
        // Send a reminder to the role with the given snowflake
        try await bot.client.createMessage(
            channelId: reminderChannel,
            payload: .init(
                content: content,
                embeds: [Utils.createBookingEmbed(for: booking, localization: config.localization)]
            )
        ).guardSuccess()
    }
}
