//
//  Booking.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

struct Booking: Codable, Hashable, Identifiable {
    let id: UUID
    var date: Date
    var author: UserSnowflake
    var worldID: String
    var roleSnowflake: RoleSnowflake?
    
    init(date: Date, author: UserSnowflake, worldID: String, roleSnowflake: RoleSnowflake? = nil) {
        self.id = UUID()
        self.date = date
        self.author = author
        self.worldID = worldID
        self.roleSnowflake = roleSnowflake
    }
}
