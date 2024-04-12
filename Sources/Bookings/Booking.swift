//
//  Booking.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

struct Booking: Codable, Hashable, Identifiable {
    private enum Constants {
        // The time at which the booking starts in hours from midnight
        static let bookingIntervalStartTime = 6
        // The time at which the booking ends in hours from midnight on the following day
        static let bookingIntervalEndTime = 5
    }
    
    let id: UUID
    var date: Date
    var author: UserSnowflake
    var worldID: String
    var roleSnowflake: RoleSnowflake?
    
    var startDate: Date {
        // The interval starts at 6 AM in the morning
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: Constants.bookingIntervalStartTime, to: startOfDay)!
    }
    
    var endDate: Date {
        // The interval ends at 5 AM the next day
        let calendar = Calendar.current
        let startOfNextDay = calendar
            .startOfDay(for: date)
            .addingTimeInterval(1 * GlobalConstants.secondsPerDay)
        return calendar.date(byAdding: .hour, value: Constants.bookingIntervalEndTime, to: startOfNextDay)!
    }
    
    init(date: Date, author: UserSnowflake, worldID: String, roleSnowflake: RoleSnowflake? = nil) {
        self.id = UUID()
        self.date = date
        self.author = author
        self.worldID = worldID
        self.roleSnowflake = roleSnowflake
    }
}
