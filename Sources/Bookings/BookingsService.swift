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
    static var dataPath: URL = Utils.baseURL.appending(path: "bookings.json")
    
    private(set) var bookings: [Booking] = loadBookings()
    
    func createBooking(at date: Date, author: UserSnowflake, worldID: String, roleSnowflake: RoleSnowflake?) {
        let booking = Booking(date: date, author: author, worldID: worldID, roleSnowflake: roleSnowflake)
        bookings.append(booking)
    }
    
    func deleteBooking(_ booking: Booking) {
        deleteBooking(id: booking.id)
    }
    
    func deleteBooking(id: Booking.ID) {
        bookings.removeAll(where: { $0.id == id })
        saveBookings()
    }
}

// MARK: - Saving
extension BookingsService {
    func saveBookings() {
        do {
            let data = try JSONEncoder().encode(self.bookings)
            try data.write(to: Self.dataPath)
        } catch {
            Self.logger.error("Failed to save bookings: \(error)")
        }
    }
    
    private static func loadBookings() -> [Booking] {
        do {
            let data = try Data(contentsOf: Self.dataPath)
            return try JSONDecoder().decode([Booking].self, from: data)
        } catch {
            Self.logger.error("Failed to load bookings: \(error)")
            return []
        }
    }
}
