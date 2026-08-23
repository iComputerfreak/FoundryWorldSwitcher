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
    
    init(dueDate: Date, eventType: SchedulerEventType) {
        self.id = UUID()
        self.dueDate = dueDate
        self.eventType = eventType
    }
    
    func execute() async throws {
        switch eventType {
        case let .consoleMessage(message):
            try await handleConsoleMessage(message)
            
        case let .lockWorldSwitching(worldID: worldID):
            try await handleLockWorldSwitching(worldID: worldID)
            
        case .unlockWorldSwitching:
            try await handleUnlockWorld()
            
        case let .sendSessionReminder(bookingID: bookingID):
            try await handleSendSessionReminder(bookingID: bookingID)
            
        case let .sendSessionStartsReminder(bookingID: bookingID):
            try await handleSendSessionStartsReminder(bookingID: bookingID)
            
        case .removeBooking:
            // Do nothing. We don't delete bookings anymore when they are completed
            break

        case let .closeDatePoll(pollID: pollID):
            try await handleCloseDatePoll(pollID: pollID)

        case let .sendDatePollReminder(pollID: pollID, userID: userID):
            try await handleDatePollReminder(pollID: pollID, userID: userID)
        }
    }
}

// MARK: - Date Polls
extension SchedulerEvent {
    private func handleCloseDatePoll(pollID: String) async throws {
        guard let poll = try await datePollsService.closePoll(id: pollID) else { return }
        guard let messageID = poll.messageID else { return }
        try await bot.client.updateMessage(
            channelId: poll.channelID,
            messageId: messageID,
            payload: DatePollRenderer.messagePayload(for: poll)
        ).guardSuccess()
    }

    private func handleDatePollReminder(pollID: String, userID: UserSnowflake) async throws {
        guard let poll = try await datePollsService.reminderPoll(pollID: pollID, userID: userID) else { return }
        guard let messageID = poll.messageID else { return }
        let pollLink = "https://discord.com/channels/\(poll.guildID.rawValue)/\(poll.channelID.rawValue)/\(messageID.rawValue)"
        let payload = Payloads.CreateMessage(
            content: "\(DiscordUtils.mention(id: userID)) please vote in the [session date poll](\(pollLink)).",
            components: DatePollRenderer.reminderComponents(for: poll)
        )

        do {
            let channel = try await bot.client.createDm(payload: .init(recipient_id: userID)).decode()
            try await bot.client.createMessage(channelId: channel.id, payload: payload).guardSuccess()
        } catch {
            try await bot.client.createMessage(channelId: poll.channelID, payload: payload).guardSuccess()
        }
        await datePollsService.markReminderDelivered(pollID: pollID, userID: userID)
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
    private func handleLockWorldSwitching(worldID: String) async throws {
        Self.logger.debug("Locking world '\(worldID)'")
        // Lock the world with the given ID
        try await PterodactylAPI.shared.changeWorld(to: worldID, restart: true)
        try WorldLockService.shared.lockWorldSwitching()
    }
}

// MARK: - Unlock World
extension SchedulerEvent {
    private func handleUnlockWorld() async throws {
        Self.logger.debug("Unlocking world switching")
        // Unlock the world with the given ID
        try WorldLockService.shared.unlockWorldSwitching()
    }
}

// MARK: - Send Session Reminder
extension SchedulerEvent {
    private func handleSendSessionReminder(bookingID: UUID) async throws {
        guard let booking = await bookingsService.booking(id: bookingID) as? EventBooking else {
            Self.logger.error("Booking with ID \(bookingID) not found.")
            return
        }
        
        Self.logger.debug("Sending session reminder for session at \(booking.date)")
        guard let reminderChannel = BotConfig.shared.reminderChannel else {
            Self.logger.warning("There is no reminder channel set up in which to send the message.")
            return
        }
        
        // Send a reminder to the role with the given snowflake
        try await bot.client.createMessage(
            channelId: reminderChannel,
            payload: .init(
                content: """
                \(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) **Reminder**: Your session is booked for \(DiscordUtils.timestamp(date: booking.date)).
                """.trimmingCharacters(in: .whitespacesAndNewlines),
                embeds: [Utils.createBookingEmbed(for: booking)]
            )
        ).guardSuccess()
    }
}

// MARK: - Send Session Starts Reminder
extension SchedulerEvent {
    private func handleSendSessionStartsReminder(bookingID: UUID) async throws {
        guard let booking = await bookingsService.booking(id: bookingID) as? EventBooking else {
            Self.logger.error("Booking with ID \(bookingID) not found.")
            return
        }
        
        Self.logger.debug("Sending session starts reminder for session at \(booking.date)")
        guard let reminderChannel = BotConfig.shared.reminderChannel else {
            Self.logger.warning("There is no reminder channel set up in which to send the message.")
            return
        }
        
        let durationString = Utils.durationString(for: BotConfig.shared.sessionStartReminderTime, unitStyle: .long)
        // Send a reminder to the role with the given snowflake
        try await bot.client.createMessage(
            channelId: reminderChannel,
            payload: .init(
                content: """
                \(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) Your session starts in \(durationString) in channel \(DiscordUtils.mention(id: booking.location)).
                """.trimmingCharacters(in: .whitespacesAndNewlines),
                embeds: [Utils.createBookingEmbed(for: booking)]
            )
        ).guardSuccess()
    }
}
