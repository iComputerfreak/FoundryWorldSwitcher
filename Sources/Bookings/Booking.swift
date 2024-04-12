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
        /// The time at which the booking starts in hours from midnight
        static let bookingIntervalStartTime = 6
        /// The time at which the booking ends in hours from midnight on the following day
        static let bookingIntervalEndTime = 5
    }
    
    let id: UUID
    /// The date of the booking
    var date: Date
    /// The user that created the booking
    var author: UserSnowflake
    /// The ID of the world on the Pterodactyl server that is being booked
    var worldID: String
    /// The group of players that are playing at this booking. If the booking is only for DM preparation, set this to `nil`.
    var campaignRoleSnowflake: RoleSnowflake?
    /// The channel where the booking is taking place
    var location: ChannelSnowflake?
    /// The topic of the booking (e.g., "Session 13")
    var topic: String?
    
    /// The start date of the booking interval. The server will be locked to the world starting at this time.
    var bookingIntervalStartDate: Date {
        // The interval starts at 6 AM in the morning
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: Constants.bookingIntervalStartTime, to: startOfDay)!
    }
    
    /// The end date of the booking interval. The server will be unlocked at this time.
    var bookingIntervalEndDate: Date {
        // The interval ends at 5 AM the next day
        let calendar = Calendar.current
        let startOfNextDay = calendar
            .startOfDay(for: date)
            .addingTimeInterval(1 * GlobalConstants.secondsPerDay)
        return calendar.date(byAdding: .hour, value: Constants.bookingIntervalEndTime, to: startOfNextDay)!
    }
    
    /// Creates a new booking with associated event information and a player role to notify before the event starts
    init(
        date: Date,
        author: UserSnowflake,
        worldID: String,
        campaignRoleSnowflake: RoleSnowflake? = nil,
        location: ChannelSnowflake? = nil,
        topic: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.author = author
        self.worldID = worldID
        self.campaignRoleSnowflake = campaignRoleSnowflake
        self.location = location
        self.topic = topic
    }
}
