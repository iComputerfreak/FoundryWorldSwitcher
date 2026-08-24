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
    init(dataPath: URL = Utils.dataURL.appendingPathComponent("booking_conflicts.json")) throws {
        self.dataPath = dataPath
        if FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                records = try JSONDecoder().decode([GlobalBookingRecord].self, from: Data(contentsOf: dataPath))
            } catch {
                throw PersistentStateError.load(dataPath, error)
            }
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
        records.append(contentsOf: bookings.filter {
            !$0.wasCancelled && $0.worldID != nil && $0.bookingIntervalEndDate(using: configuration) > .now
        }.map {
            .init(
                bookingID: $0.id,
                guildID: guildID,
                startDate: $0.bookingIntervalStartDate(using: configuration),
                endDate: $0.bookingIntervalEndDate(using: configuration)
            )
        })
        save()
    }

    /// Removes conflict records owned by guilds the bot no longer belongs to.
    func prune(guildIDs: Set<GuildSnowflake>) {
        let originalCount = records.count
        records.removeAll { !guildIDs.contains($0.guildID) }
        if records.count != originalCount {
            save()
        }
    }

    /// Removes all conflict records owned by a guild the bot no longer serves.
    func removeAll(for guildID: GuildSnowflake) {
        let originalCount = records.count
        records.removeAll { $0.guildID == guildID }
        if records.count != originalCount {
            save()
        }
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
