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
            
        case let .removeBooking(id: bookingID):
            try await handleRemoveBooking(id: bookingID)
        }
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
                \(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) Your session starts \(durationString) in channel \(DiscordUtils.mention(id: booking.location)).
                """.trimmingCharacters(in: .whitespacesAndNewlines),
                embeds: [Utils.createBookingEmbed(for: booking)]
            )
        ).guardSuccess()
    }
}

// MARK: - Delete Booking
extension SchedulerEvent {
    private func handleRemoveBooking(id: UUID) async throws {
        Self.logger.debug("Removing booking with ID \(id)")
        await bookingsService.removeBooking(id: id)
    }
}
