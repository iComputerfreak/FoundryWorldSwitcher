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
}
