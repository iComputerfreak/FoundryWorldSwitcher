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
    var wasCancelled: Bool = false
    
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
        ]
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.author = try container.decode(UserSnowflake.self, forKey: .author)
        self.worldID = try container.decode(String.self, forKey: .worldID)
        self.associatedEvents = try container.decode([SchedulerEvent].self, forKey: .associatedEvents)
        // This key was introduced in version 2.9.0 and may not exist on disk
        self.wasCancelled = try container.decodeIfPresent(Bool.self, forKey: .wasCancelled) ?? false
    }
}
