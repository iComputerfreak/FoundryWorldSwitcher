//
//  EventBooking.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

struct EventBooking: Booking {
    let id: UUID
    var date: Date
    var author: UserSnowflake
    var worldID: String
    /// The group of players that are playing at this booking. If the booking is only for DM preparation, set this to `nil`.
    var campaignRoleSnowflake: RoleSnowflake
    /// The channel where the booking is taking place
    var location: ChannelSnowflake
    /// The topic of the booking (e.g., "Session 13")
    var topic: String
    
    /// Creates a new booking with associated event information and a player role to notify before the event starts
    init(
        date: Date,
        author: UserSnowflake,
        worldID: String,
        campaignRoleSnowflake: RoleSnowflake,
        location: ChannelSnowflake,
        topic: String
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
