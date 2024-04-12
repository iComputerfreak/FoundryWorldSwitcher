//
//  ReservationBooking.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

struct ReservationBooking: Booking {
    let id: UUID
    var date: Date
    var author: UserSnowflake
    var worldID: String
    
    /// Creates a new booking without any associated event or player role information
    init(date: Date, author: UserSnowflake, worldID: String) {
        self.id = UUID()
        self.date = date
        self.author = author
        self.worldID = worldID
    }
}