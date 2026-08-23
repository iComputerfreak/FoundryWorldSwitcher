import DiscordBM
import Foundation
import Logging

/// Persists booking intervals shared by all guilds using the Foundry target.
actor GlobalBookingConflictService {
    /// Logger for conflict-index persistence failures.
    private static let logger = Logger(label: "GlobalBookingConflictService")

    /// File containing global booking conflict records.
    private let dataPath: URL

    /// In-memory global booking conflict records.
    private var records: [GlobalBookingRecord]

    /// Loads global booking conflict records from `dataPath`.
    init(dataPath: URL = Utils.dataURL.appendingPathComponent("booking_conflicts.json")) {
        self.dataPath = dataPath
        if let data = try? Data(contentsOf: dataPath) {
            records = (try? JSONDecoder().decode([GlobalBookingRecord].self, from: data)) ?? []
        } else {
            records = []
        }
    }

    /// Rebuilds one guild's conflict records from its active bookings.
    func replaceBookings(
        for guildID: GuildSnowflake,
        bookings: [any Booking],
        configuration: any BookingConfiguration
    ) {
        records.removeAll { $0.guildID == guildID }
        records.append(contentsOf: bookings.filter { !$0.wasCancelled }.map {
            .init(
                bookingID: $0.id,
                guildID: guildID,
                startDate: $0.bookingIntervalStartDate(using: configuration),
                endDate: $0.bookingIntervalEndDate(using: configuration)
            )
        })
        save()
    }

    /// Reserves an active booking interval when it does not conflict globally.
    func reserve(
        _ booking: any Booking,
        for guildID: GuildSnowflake,
        configuration: any BookingConfiguration
    ) throws {
        let startDate = booking.bookingIntervalStartDate(using: configuration)
        let endDate = booking.bookingIntervalEndDate(using: configuration)
        if let conflict = records.first(where: {
            $0.bookingID != booking.id && $0.startDate < endDate && startDate < $0.endDate
        }) {
            throw GlobalBookingConflictError.conflict(conflict)
        }
        records.removeAll { $0.bookingID == booking.id && $0.guildID == guildID }
        records.append(.init(bookingID: booking.id, guildID: guildID, startDate: startDate, endDate: endDate))
        save()
    }

    /// Removes one booking from the global conflict index.
    func remove(bookingID: UUID, guildID: GuildSnowflake) {
        records.removeAll { $0.bookingID == bookingID && $0.guildID == guildID }
        save()
    }

    /// Persists the global booking conflict index.
    private func save() {
        do {
            try JSONEncoder().encode(records).write(to: dataPath)
        } catch {
            Self.logger.error("Failed to save booking conflict index: \(error)")
        }
    }
}
