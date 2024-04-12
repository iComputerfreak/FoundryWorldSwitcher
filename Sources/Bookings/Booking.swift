//
//  Booking.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

protocol Booking: Codable, Hashable, Identifiable {
    /// The ID of the booking
    var id: UUID { get }
    /// The date of the booking
    var date: Date { get set }
    /// The user that created the booking
    var author: UserSnowflake { get set }
    /// The ID of the world on the Pterodactyl server that is being booked
    var worldID: String { get set }
    /// The scheduler events associated with this booking
    var associatedEvents: [SchedulerEvent] { get }
}

// MARK: - Booking Interval
extension Booking {
    /// The start date of the booking interval. The server will be locked to the world starting at this time.
    var bookingIntervalStartDate: Date {
        // The interval starts at 6 AM in the morning
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: GlobalConstants.bookingIntervalStartTime, to: startOfDay)!
    }
    
    /// The end date of the booking interval. The server will be unlocked at this time.
    var bookingIntervalEndDate: Date {
        // The interval ends at 5 AM the next day
        let calendar = Calendar.current
        let startOfNextDay = calendar
            .startOfDay(for: date)
            .addingTimeInterval(1 * GlobalConstants.secondsPerDay)
        return calendar.date(byAdding: .hour, value: GlobalConstants.bookingIntervalEndTime, to: startOfNextDay)!
    }
}
