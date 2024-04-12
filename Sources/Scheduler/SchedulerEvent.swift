//
//  SchedulerEvent.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

struct SchedulerEvent: Codable, Hashable, Identifiable {
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
        case let .lockWorld(worldID: worldID):
            return
            
        case let .unlockWorld(worldID: worldID):
            return
            
        case let .sendSessionReminder(roleSnowflake: roleSnowflake, sessionDate: sessionDate):
            return
        }
    }
}

// MARK: - Lock World
extension SchedulerEvent {
    private func handleLockWorld(worldID: String) async throws {
        // Lock the world with the given ID
    }
}

// MARK: - Unlock World
extension SchedulerEvent {
    private func handleUnlockWorld(worldID: String) async throws {
        // Unlock the world with the given ID
    }
}

// MARK: - Send Session Reminder
extension SchedulerEvent {
    private func handleSendSessionReminder(roleSnowflake: RoleSnowflake, sessionDate: Date) async throws {
        // Send a reminder to the role with the given snowflake
    }
}
