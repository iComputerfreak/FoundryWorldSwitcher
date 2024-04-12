//
//  GlobalConstants.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import Foundation

enum GlobalConstants {
    static let secondsPerDay: TimeInterval = 24 * secondsPerHour
    static let secondsPerHour: TimeInterval = 60 * secondsPerMinute
    static let secondsPerMinute: TimeInterval = 60
    
    // TODO: Move to config
    static let sessionLength: TimeInterval = 4 * secondsPerHour
    /// The time at which the booking starts in hours from midnight
    static let bookingIntervalStartTime = 6
    /// The time at which the booking ends in hours from midnight on the following day
    static let bookingIntervalEndTime = 5
    /// The time how much in advance the bot will remind players about a session
    static let sessionReminderTime = 1 * secondsPerDay
    /// Whether the bot should notify players at the start of the session
    static let shouldNotifyAtSessionStart = true
    /// The time how much in advance the bot will remind players that the session is about to start
    static let sessionStartReminderTime: TimeInterval = 5 * secondsPerMinute
}
