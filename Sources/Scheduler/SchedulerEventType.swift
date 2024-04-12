//
//  SchedulerEventType.swift
//  
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

enum SchedulerEventType: Codable, Hashable {
    case consoleMessage(_ message: String)
    case lockWorld(worldID: String)
    case unlockWorld(worldID: String)
    case sendSessionReminder(roleSnowflake: RoleSnowflake, sessionDate: Date)
    case sendSessionStartsReminder(roleSnowflake: RoleSnowflake, sessionDate: Date)
}
