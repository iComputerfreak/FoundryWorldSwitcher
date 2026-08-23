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
    /// The optional ID of the Foundry world associated with this booking.
    var worldID: String? { get set }
    /// The scheduler events associated with this booking
    var associatedEvents: [SchedulerEvent] { get }
    /// Persisted start of the world-lock interval.
    var bookingIntervalStartDate: Date? { get set }
    /// Persisted end of the world-lock interval.
    var bookingIntervalEndDate: Date? { get set }
    /// Whether the booking was cancelled
    var wasCancelled: Bool { get set }
}

// MARK: - Booking Interval
extension Booking {
    func bookingIntervalStartDate(using configuration: any BookingConfiguration) -> Date {
        bookingIntervalStartDate ?? Calendar.current.startOfDay(for: date)
            .addingTimeInterval(configuration.bookingIntervalStartTime)
    }

    func bookingIntervalEndDate(using configuration: any BookingConfiguration) -> Date {
        bookingIntervalEndDate ?? bookingIntervalStartDate(using: configuration)
            .addingTimeInterval(configuration.bookingIntervalEndTime)
    }

    @discardableResult
    mutating func initializeBookingInterval(using configuration: any BookingConfiguration) -> Bool {
        guard worldID != nil else { return false }
        guard
            bookingIntervalStartDate == nil || bookingIntervalEndDate == nil ||
            bookingIntervalEndDate! <= bookingIntervalStartDate!
        else {
            return false
        }

        if
            let lockEvent = associatedEvents.first(where: {
                if case .lockWorldSwitching = $0.eventType { return true }
                return false
            }),
            let unlockEvent = associatedEvents.first(where: {
                if case .unlockWorldSwitching = $0.eventType { return true }
                return false
            }),
            unlockEvent.dueDate > lockEvent.dueDate
        {
            bookingIntervalStartDate = lockEvent.dueDate
            bookingIntervalEndDate = unlockEvent.dueDate
        } else {
            // Legacy records without interval events use the config once, then persist it.
            let startDate = Calendar.current.startOfDay(for: date)
                .addingTimeInterval(configuration.bookingIntervalStartTime)
            bookingIntervalStartDate = startDate
            bookingIntervalEndDate = startDate.addingTimeInterval(configuration.bookingIntervalEndTime)
        }
        return true
    }

    func defaultBookingIntervalStartDate(using configuration: any BookingConfiguration) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return startOfDay.addingTimeInterval(configuration.bookingIntervalStartTime)
    }
}
