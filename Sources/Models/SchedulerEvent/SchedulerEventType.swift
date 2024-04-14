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
    case lockWorldSwitching(worldID: String)
    case unlockWorldSwitching
    case sendSessionReminder(bookingID: UUID)
    case sendSessionStartsReminder(bookingID: UUID)
    case removeBooking(id: UUID)
}
