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
    var associatedEvents: [SchedulerEvent] = []
    
    /// Creates a new booking without any associated event or player role information
    init(date: Date, author: UserSnowflake, worldID: String) {
        self.id = UUID()
        self.date = date
        self.author = author
        self.worldID = worldID
        self.associatedEvents = [
            SchedulerEvent(
                dueDate: bookingIntervalStartDate,
                eventType: .lockWorldSwitching(worldID: worldID)
            ),
            SchedulerEvent(
                dueDate: bookingIntervalEndDate,
                eventType: .unlockWorldSwitching
            ),
            SchedulerEvent(
                dueDate: bookingIntervalEndDate,
                eventType: .removeBooking(id: id)
            ),
        ]
    }
}
