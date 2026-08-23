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
    var worldID: String?
    var associatedEvents: [SchedulerEvent] = []
    var bookingIntervalStartDate: Date?
    var bookingIntervalEndDate: Date?
    var wasCancelled: Bool = false
    
    /// Creates a new booking without any associated event or player role information
    init(
        id: UUID = UUID(),
        date: Date,
        author: UserSnowflake,
        worldID: String,
        configuration: any BookingConfiguration
    ) {
        self.id = id
        self.date = date
        self.author = author
        self.worldID = worldID
        self.bookingIntervalStartDate = defaultBookingIntervalStartDate(using: configuration)
        self.bookingIntervalEndDate = bookingIntervalStartDate!.addingTimeInterval(configuration.bookingIntervalEndTime)
        self.associatedEvents = [
            SchedulerEvent(
                dueDate: bookingIntervalStartDate!,
                eventType: .lockWorldSwitching(worldID: worldID)
            ),
            SchedulerEvent(
                dueDate: bookingIntervalEndDate!,
                eventType: .unlockWorldSwitching
            ),
        ]
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.author = try container.decode(UserSnowflake.self, forKey: .author)
        self.worldID = try container.decodeIfPresent(String.self, forKey: .worldID)
        self.associatedEvents = try container.decode([SchedulerEvent].self, forKey: .associatedEvents)
        self.bookingIntervalStartDate = try container.decodeIfPresent(Date.self, forKey: .bookingIntervalStartDate)
        self.bookingIntervalEndDate = try container.decodeIfPresent(Date.self, forKey: .bookingIntervalEndDate)
        // This key was introduced in version 2.9.0 and may not exist on disk
        self.wasCancelled = try container.decodeIfPresent(Bool.self, forKey: .wasCancelled) ?? false
    }
}
