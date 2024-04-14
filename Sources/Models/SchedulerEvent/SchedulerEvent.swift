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
            
        case let .sendSessionReminder(sessionDate: date, roleSnowflake: role, location: location, topic: topic):
            try await handleSendSessionReminder(
                sessionDate: date,
                roleSnowflake: role,
                location: location,
                topic: topic
            )
            
        case let .sendSessionStartsReminder(sessionDate: date, roleSnowflake: role, location: location, topic: topic):
            try await handleSendSessionStartsReminder(
                sessionDate: date,
                roleSnowflake: role,
                location: location,
                topic: topic
            )
            
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
        try await PterodactylAPI.shared.changeWorld(to: worldID)
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
    private func handleSendSessionReminder(
        sessionDate: Date,
        roleSnowflake: RoleSnowflake,
        location: ChannelSnowflake,
        topic: String
    ) async throws {
        Self.logger.debug("Sending session reminder for session at \(sessionDate)")
        guard let reminderChannel = BotConfig.shared.reminderChannel else {
            Self.logger.warning("There is no reminder channel set up in which to send the message.")
            return
        }
        // Send a reminder to the role with the given snowflake
        try await bot.client.createMessage(
            channelId: reminderChannel,
            payload: .init(
                content: """
                \(DiscordUtils.mention(id: roleSnowflake))
                **Reminder**: Your session starts \(DiscordUtils.timestamp(date: sessionDate)) in channel \(DiscordUtils.mention(id: location)).
                > \(topic)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        ).guardSuccess()
    }
}

// MARK: - Send Session Starts Reminder
extension SchedulerEvent {
    private func handleSendSessionStartsReminder(
        sessionDate: Date,
        roleSnowflake: RoleSnowflake,
        location: ChannelSnowflake,
        topic: String
    ) async throws {
        Self.logger.debug("Sending session starts reminder for session at \(sessionDate)")
        guard let reminderChannel = BotConfig.shared.reminderChannel else {
            Self.logger.warning("There is no reminder channel set up in which to send the message.")
            return
        }
        // Send a reminder to the role with the given snowflake
        try await bot.client.createMessage(
            channelId: reminderChannel,
            payload: .init(
                content: """
                \(DiscordUtils.mention(id: roleSnowflake))
                Your session starts now in channel \(DiscordUtils.mention(id: location)).
                > \(topic)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
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
