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
    }

    static let logger: Logger = .init(label: String(describing: BookingsService.self))
    
    let scheduler: Scheduler
    let dataPath: URL
    let configuration: any BookingConfiguration
    let pinnedMessagesConfiguration: GuildConfig
    let guildID: GuildSnowflake
    let bookingConflicts: GlobalBookingConflictService
    private var transitioningBookingIDs: Set<UUID> = []
    private var transitionWaiters: [UUID: [CheckedContinuation<Void, Never>]] = [:]
    private var reservingBookingDates: Set<Date> = []
    private var dateReservationWaiters: [Date: [CheckedContinuation<Void, Never>]] = [:]
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

    var allBookings: [any Booking] {
        bookings
    }
    
    var activeBookings: [any Booking] {
        bookings
            .filter { $0.bookingIntervalEndDate(using: configuration) > .now }
            .filter { !$0.wasCancelled }
    }
    
    var cancelledBookings: [any Booking] {
        bookings.filter { $0.wasCancelled }
    }
    
    var completedBookings: [any Booking] {
        bookings
            .filter { $0.bookingIntervalEndDate(using: configuration) < .now }
            .filter { !$0.wasCancelled }
    }
    
    init(
        scheduler: Scheduler,
        dataPath: URL,
        configuration: any BookingConfiguration,
        pinnedMessagesConfiguration: GuildConfig,
        guildID: GuildSnowflake,
        bookingConflicts: GlobalBookingConflictService
    ) throws {
        self.scheduler = scheduler
        self.dataPath = dataPath
        self.configuration = configuration
        self.pinnedMessagesConfiguration = pinnedMessagesConfiguration
        self.guildID = guildID
        self.bookingConflicts = bookingConflicts
        let loadedBookings = try Self.loadBookings(from: dataPath, configuration: configuration)
        self.bookings = loadedBookings.bookings
        if loadedBookings.didInitializeIntervals {
            try Self.save(BookingList(bookings: bookings), at: dataPath)
        }
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

    func booking(associatedEventID eventID: SchedulerEvent.ID) -> (any Booking)? {
        bookings.first { booking in
            !booking.wasCancelled && booking.associatedEvents.contains(where: { $0.id == eventID })
        }
    }
    
    /// Adds the given booking to the store and schedules its events.
    private func createBooking(_ booking: any Booking) async {
        bookings.append(booking)
        saveBookings()
        await scheduler.schedule(booking.associatedEvents)
    }

    func createBookingIfAvailable(_ booking: any Booking) async throws {
        let bookingDate = Calendar.current.startOfDay(for: booking.date)
        await beginDateReservation(for: bookingDate)
        defer { endDateReservation(for: bookingDate) }

        guard self.booking(at: booking.date) == nil else {
            throw DiscordCommandError.bookingAlreadyExists(atDate: booking.date)
        }
        if booking.worldID != nil {
            try await bookingConflicts.reserve(booking, for: guildID, configuration: configuration)
        }
        await createBooking(booking)
    }

    /// Replaces a booking after reserving its new interval without releasing its existing one.
    func rescheduleBooking(id: UUID, to date: Date) async throws -> (any Booking)? {
        await beginTransition(for: id)
        defer { endTransition(for: id) }

        guard let originalBooking = bookings.first(where: { $0.id == id }) else { return nil }
        guard date > .now else { throw DiscordCommandError.dateIsInThePast(date) }
        let bookingDate = Calendar.current.startOfDay(for: date)
        await beginDateReservation(for: bookingDate)
        defer { endDateReservation(for: bookingDate) }
        guard !bookings.contains(where: {
            $0.id != id && Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else {
            throw DiscordCommandError.bookingAlreadyExists(atDate: date)
        }

        let replacementBooking: any Booking
        if let booking = originalBooking as? EventBooking {
            replacementBooking = EventBooking(
                id: booking.id,
                date: date,
                author: booking.author,
                worldID: booking.worldID,
                campaignRoleSnowflake: booking.campaignRoleSnowflake,
                location: booking.location,
                topic: booking.topic,
                configuration: configuration
            )
        } else if let booking = originalBooking as? ReservationBooking {
            guard let worldID = booking.worldID else { return nil }
            replacementBooking = ReservationBooking(
                id: booking.id,
                date: date,
                author: booking.author,
                worldID: worldID,
                configuration: configuration
            )
        } else {
            return nil
        }

        if replacementBooking.worldID != nil {
            try await bookingConflicts.reserve(replacementBooking, for: guildID, configuration: configuration)
        }

        if originalBooking.worldID != nil {
            do {
                _ = try WorldLockService.shared.unlockWorldSwitching(guildID: guildID, bookingID: originalBooking.id)
            } catch {
                try? await bookingConflicts.reserve(originalBooking, for: guildID, configuration: configuration)
                throw error
            }
        }

        guard let index = bookings.firstIndex(where: { $0.id == id }) else {
            if originalBooking.worldID != nil {
                try? await bookingConflicts.reserve(originalBooking, for: guildID, configuration: configuration)
            }
            return nil
        }
        bookings[index] = replacementBooking
        await scheduler.unqueue(originalBooking.associatedEvents)
        await scheduler.schedule(replacementBooking.associatedEvents)
        return replacementBooking
    }
    
    /// Deletes the given booking from the store and unqueues any associated events
    func deleteBooking(_ booking: any Booking) async {
        await beginTransition(for: booking.id)
        defer { endTransition(for: booking.id) }
        guard let index = bookings.firstIndex(where: { $0.id == booking.id }) else { return }
        let currentBooking = bookings[index]

        bookings.remove(at: index)
        if currentBooking.worldID != nil {
            _ = try? WorldLockService.shared.unlockWorldSwitching(guildID: guildID, bookingID: currentBooking.id)
        }
        await scheduler.unqueue(currentBooking.associatedEvents)
        if currentBooking.worldID != nil {
            await bookingConflicts.remove(bookingID: currentBooking.id, guildID: guildID)
        }
    }
    
    /// Deletes the booking with the given ID from the store
    ///
    /// - NOTE: Does **not** unqueue any associated events.
    private func removeBooking(id: UUID) {
        bookings.removeAll(where: { $0.id == id })
        saveBookings()
    }
    
    /// Cancels the booking with the given ID and unqueues any associated events
    func cancelBooking(id: UUID) async {
        await beginTransition(for: id)
        defer { endTransition(for: id) }
        guard let bookingIndex = bookings.firstIndex(where: { $0.id == id }) else {
            Self.logger.warning("Trying to cancel booking with ID \(id), but no booking with that ID exists.")
            return
        }

        let booking = bookings[bookingIndex]
        bookings[bookingIndex].wasCancelled = true
        if booking.worldID != nil {
            _ = try? WorldLockService.shared.unlockWorldSwitching(guildID: guildID, bookingID: booking.id)
        }
        await scheduler.unqueue(booking.associatedEvents)
        if booking.worldID != nil {
            await bookingConflicts.remove(bookingID: booking.id, guildID: guildID)
        }
    }

    /// Cancels every active booking when this guild loses Foundry feature access.
    func cancelAllBookings() async {
        let bookingIDs = activeBookings.filter { $0.worldID != nil }.map(\.id)
        for bookingID in bookingIDs {
            await cancelBooking(id: bookingID)
        }
        saveBookings()
    }

    /// Locks and starts the world for an event after serializing its booking lifecycle.
    func startWorldSwitching(eventID: SchedulerEvent.ID, worldID: String) async throws {
        guard let bookingID = booking(associatedEventID: eventID)?.id else {
            Self.logger.warning("Skipping lock event \(eventID): no active booking owns it.")
            return
        }
        await beginTransition(for: bookingID)
        defer { endTransition(for: bookingID) }

        guard let booking = booking(associatedEventID: eventID), booking.worldID == worldID else {
            Self.logger.warning("Skipping lock event \(eventID): its booking changed.")
            return
        }
        guard booking.bookingIntervalEndDate(using: configuration) > .now else {
            Self.logger.warning("Skipping lock event \(eventID): booking interval has ended.")
            return
        }

        try WorldLockService.shared.lockWorldSwitching(guildID: guildID, bookingID: booking.id)
        do {
            try await PterodactylAPI.shared.changeWorld(to: worldID, restart: true)
        } catch {
            _ = try? WorldLockService.shared.unlockWorldSwitching(guildID: guildID, bookingID: booking.id)
            throw error
        }
    }

    private func beginTransition(for bookingID: UUID) async {
        while transitioningBookingIDs.contains(bookingID) {
            await withCheckedContinuation { continuation in
                transitionWaiters[bookingID, default: []].append(continuation)
            }
        }
        transitioningBookingIDs.insert(bookingID)
    }

    private func endTransition(for bookingID: UUID) {
        transitioningBookingIDs.remove(bookingID)
        let waiters = transitionWaiters.removeValue(forKey: bookingID) ?? []
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func beginDateReservation(for date: Date) async {
        while reservingBookingDates.contains(date) {
            await withCheckedContinuation { continuation in
                dateReservationWaiters[date, default: []].append(continuation)
            }
        }
        reservingBookingDates.insert(date)
    }

    private func endDateReservation(for date: Date) {
        reservingBookingDates.remove(date)
        let waiters = dateReservationWaiters.removeValue(forKey: date) ?? []
        for waiter in waiters {
            waiter.resume()
        }
    }
}

// MARK: - Loading / Saving
extension BookingsService {
    func saveBookings() {
        do {
            let list = BookingList(bookings: bookings)
            try Self.save(list, at: dataPath)
        } catch {
            Self.logger.error("Failed to save bookings: \(error)")
        }
    }
    
    static func loadBookings(
        from url: URL,
        configuration: any BookingConfiguration
    ) throws -> (bookings: [any Booking], didInitializeIntervals: Bool) {
        let bookingList: BookingList? = try Self.load(from: url, defaultValue: nil)
        var bookings = bookingList?.allBookings ?? []
        var didInitializeIntervals = false
        for index in bookings.indices {
            didInitializeIntervals = bookings[index].initializeBookingInterval(using: configuration) || didInitializeIntervals
        }
        return (bookings, didInitializeIntervals)
    }
    
    private static func save<T: Encodable>(_ object: T, at url: URL) throws {
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
        let messages = pinnedMessagesConfiguration.pinnedBookingMessages
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
            let filteredBookings = activeBookings
                .filter { pinnedMessagesConfiguration.foundryFeaturesEnabled || $0.worldID == nil }
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
                    pinnedMessagesConfiguration.pinnedBookingMessages.removeAll(where: { $0.messageID == message.messageID && $0.channelID == message.channelID })
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
