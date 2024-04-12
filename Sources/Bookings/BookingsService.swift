//
//  PersistentBookingsService.swift
//  
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation
import Logging

actor BookingsService {
    static var logger: Logger = .init(label: String(describing: BookingsService.self))
    static var reservationBookingsDataPath: URL = Utils.baseURL.appending(path: "reservation_bookings.json")
    static var eventBookingsDataPath: URL = Utils.baseURL.appending(path: "event_bookings.json")
    
    private(set) var reservationBookings: [ReservationBooking] = loadBookings(from: reservationBookingsDataPath)
    private(set) var eventBookings: [EventBooking] = loadBookings(from: eventBookingsDataPath)
    
    /// All bookings
    private(set) var bookings: [any Booking] {
        get {
            reservationBookings + eventBookings
        }
        set {
            reservationBookings = newValue.compactMap { $0 as? ReservationBooking }
            eventBookings = newValue.compactMap { $0 as? EventBooking }
        }
    }
    
    /// Adds the given booking to the store
    func createBooking(_ booking: any Booking) {
        bookings.append(booking)
        saveBookings()
    }
    
    /// Deletes the given booking from the store
    func deleteBooking(_ booking: any Booking) {
        deleteBooking(id: booking.id)
    }
    
    /// Deletes the booking with the given ID from the store
    func deleteBooking(id: UUID) {
        bookings.removeAll(where: { $0.id == id })
        saveBookings()
    }
}

// MARK: - Saving
extension BookingsService {
    func saveBookings() {
        do {
            try save(self.reservationBookings, at: Self.reservationBookingsDataPath)
            try save(self.eventBookings, at: Self.eventBookingsDataPath)
        } catch {
            Self.logger.error("Failed to save bookings: \(error)")
        }
    }
    
    private func save<B: Booking>(_ bookings: [B], at url: URL) throws {
        let data = try JSONEncoder().encode(bookings)
        try data.write(to: url)
    }
    
    private static func loadBookings<B: Booking>(from url: URL) -> [B] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([B].self, from: data)
        } catch {
            Self.logger.error("Failed to load bookings: \(error)")
            return []
        }
    }
}
