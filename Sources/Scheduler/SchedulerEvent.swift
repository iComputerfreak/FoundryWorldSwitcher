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
            
        case let .lockWorld(worldID: worldID):
            try await handleLockWorld(worldID: worldID)
            
        case let .unlockWorld(worldID: worldID):
            try await handleUnlockWorld(worldID: worldID)
            
        case let .sendSessionReminder(roleSnowflake: roleSnowflake, sessionDate: sessionDate):
            try await handleSendSessionReminder(roleSnowflake: roleSnowflake, sessionDate: sessionDate)
            
        case let .sendSessionStartsReminder(roleSnowflake: roleSnowflake, sessionDate: sessionDate):
            try await handleSendSessionStartsReminder(roleSnowflake: roleSnowflake, sessionDate: sessionDate)
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
    private func handleLockWorld(worldID: String) async throws {
        Self.logger.debug("Locking world '\(worldID)'")
        // Lock the world with the given ID
    }
}

// MARK: - Unlock World
extension SchedulerEvent {
    private func handleUnlockWorld(worldID: String) async throws {
        Self.logger.debug("Unlocking world '\(worldID)'")
        // Unlock the world with the given ID
    }
}

// MARK: - Send Session Reminder
extension SchedulerEvent {
    private func handleSendSessionReminder(roleSnowflake: RoleSnowflake, sessionDate: Date) async throws {
        Self.logger.debug("Sending session reminder for session at \(sessionDate)")
        // Send a reminder to the role with the given snowflake
    }
}

// MARK: - Send Session Starts Reminder
extension SchedulerEvent {
    private func handleSendSessionStartsReminder(roleSnowflake: RoleSnowflake, sessionDate: Date) async throws {
        Self.logger.debug("Sending session starts reminder for session at \(sessionDate)")
        // Send a reminder to the role with the given snowflake
    }
}
