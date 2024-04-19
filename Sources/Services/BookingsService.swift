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
    static var reservationBookingsDataPath: URL = Utils.dataURL.appendingPathComponent("reservation_bookings.json")
    static var eventBookingsDataPath: URL = Utils.dataURL.appendingPathComponent("event_bookings.json")
    
    let scheduler: Scheduler
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
            saveBookings()
            Task { [weak self] in
                do {
                    try await self?.updatePinnedBookings()
                } catch {
                    Self.logger.error("Error updating pinned bookings: \(error)")
                }
            }
        }
    }
    
    init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }
    
    /// Returns the booking for the given date, or `nil` if no booking exists for that date
    func booking(at date: Date) -> (any Booking)? {
        // We ignore the time part of the date
        let calendar = Calendar.current
        let date = calendar.startOfDay(for: date)
        return bookings.first { booking in
            let bookingDate = calendar.startOfDay(for: booking.date)
            return bookingDate == date
        }
    }
    
    /// Returns the booking with the given ID, or `nil` if no booking exists with that ID
    func booking(id: UUID) -> (any Booking)? {
        bookings.first(where: { $0.id == id })
    }
    
    /// Adds the given booking to the store
    func createBooking(_ booking: any Booking) async {
        bookings.append(booking)
        saveBookings()
        await scheduler.schedule(booking.associatedEvents)
    }
    
    /// Deletes the given booking from the store and unqueues any associated events
    func deleteBooking(_ booking: any Booking) async {
        removeBooking(id: booking.id)
        await scheduler.unqueue(booking.associatedEvents)
    }
    
    /// Deletes the booking with the given ID from the store
    ///
    /// - NOTE: Does **not** unqueue any associated events.
    func removeBooking(id: UUID) {
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
            guard FileManager.default.fileExists(atPath: url.path) else {
                return []
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([B].self, from: data)
        } catch {
            Self.logger.error("Failed to load bookings: \(error)")
            return []
        }
    }
}

// MARK: - Pinned Bookings
extension BookingsService {
    func updatePinnedBookings() async throws {
        let messages = BotConfig.shared.pinnedBookingMessages
        Self.logger.info("Updating \(messages.count) pinned booking messages.")
        func payload(for bookings: [any Booking]) async throws -> Payloads.EditMessage {
            if bookings.isEmpty {
                return .init(
                    content: "# Upcoming Events\nThere are no bookings scheduled right now.",
                    embeds: []
                )
            } else {
                return try await .init(
                    content: "# Upcoming Events",
                    embeds: Utils.createBookingEmbeds(for: bookings)
                )
            }
        }
        for message in messages {
            let filteredBookings = bookings
                .filter { booking in
                    guard let worldID = message.worldID else {
                        return true
                    }
                    return booking.worldID == worldID
                }
                .filter { booking in
                    guard let role = message.role else {
                        // If there is no role filter, include the booking
                        return true
                    }
                    guard let eventBooking = booking as? EventBooking else {
                        // If the booking is a reservation, exclude it
                        return false
                    }
                    return eventBooking.campaignRoleSnowflake == role
                }
            try await bot.client.updateMessage(
                channelId: message.channelID,
                messageId: message.messageID,
                payload: payload(for: filteredBookings)
            ).guardSuccess()
        }
    }
}
