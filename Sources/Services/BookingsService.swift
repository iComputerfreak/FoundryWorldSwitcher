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
    private enum Constants {
        static let notFoundStatusCode: UInt = 404
        
        static let bookingsDataPath: URL = Utils.dataURL.appendingPathComponent("bookings.json")
    }

    static let logger: Logger = .init(label: String(describing: BookingsService.self))
    
    let scheduler: Scheduler
    private(set) var bookings: [any Booking] {
        didSet {
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
    
    var activeBookings: [any Booking] {
        bookings.filter { !$0.wasCancelled }
    }
    
    var cancelledBookings: [any Booking] {
        bookings.filter { $0.wasCancelled }
    }
    
    init(scheduler: Scheduler) {
        self.scheduler = scheduler
        self.bookings = Self.loadBookings(from: Constants.bookingsDataPath)
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
    func booking(id: UUID, includeCancelled: Bool = false) -> (any Booking)? {
        bookings.first(where: { $0.id == id && (includeCancelled || !$0.wasCancelled) })
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
    
    /// Cancels the booking with the given ID and unqueues any associated events
    func cancelBooking(id: UUID) async {
        guard var bookingIndex = bookings.firstIndex(where: { $0.id == id }) else {
            Self.logger.warning("Trying to cancel booking with ID \(id), but no booking with that ID exists.")
            return
        }
        await scheduler.unqueue(bookings[bookingIndex].associatedEvents)
        bookings[bookingIndex].wasCancelled = true
    }
}

// MARK: - Loading / Saving
extension BookingsService {
    func saveBookings() {
        do {
            let list = BookingList(bookings: bookings)
            try save(list, at: Constants.bookingsDataPath)
        } catch {
            Self.logger.error("Failed to save bookings: \(error)")
        }
    }
    
    static func loadBookings(from url: URL) -> [any Booking] {
        let bookingList: BookingList? = try? Self.load(from: Constants.bookingsDataPath, defaultValue: nil)
        // Migrate old files if they exist
        return bookingList?.allBookings ?? migrateOldData() ?? []
    }
    
    private func save<T: Encodable>(_ object: T, at url: URL) throws {
        let data = try JSONEncoder().encode(object)
        try data.write(to: url)
    }
    
    private static func load<T: Decodable>(from url: URL, defaultValue: T) throws -> T {
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return defaultValue
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Self.logger.error("Failed to load bookings: \(error)")
            throw error
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
        
        var errors: [Error] = []
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
            
            do {
                try await bot.client.updateMessage(
                    channelId: message.channelID,
                    messageId: message.messageID,
                    payload: payload(for: filteredBookings)
                ).guardSuccess()
            } catch let error as DiscordHTTPError {
                if
                    case let DiscordHTTPError.badStatusCode(response) = error,
                    response.status.code == Constants.notFoundStatusCode
                {
                    Self.logger.error(
                        // swiftlint:disable:next line_length
                        "Received 404 error while updating pinned bookings for message id \(message.messageID.rawValue) in channel \(message.channelID.rawValue). Removing it from the list of pinned messages."
                    )
                    BotConfig.shared.pinnedBookingMessages.removeAll(where: { $0.messageID == message.messageID && $0.channelID == message.channelID })
                } else {
                    // Rethrow non-404 errors
                    throw error
                }
            } catch {
                // Collect all other errors and throw them after updating the other messages.
                // We don't want a single error preventing other messages from receiving updates.
                errors.append(error)
            }
        }
        
        // If we had any errors, throw them
        if errors.count > 1 {
            throw CompoundError(errors: errors)
        } else if let error = errors.first {
            throw error
        }
    }
}
