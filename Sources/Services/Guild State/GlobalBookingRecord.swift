import DiscordBM
import Foundation

/// A guild booking interval in the global Foundry conflict index.
struct GlobalBookingRecord: Codable, Hashable {
    /// Persisted booking identifier.
    let bookingID: UUID

    /// Guild that owns the booking.
    let guildID: GuildSnowflake

    /// Start of the world-lock interval.
    let startDate: Date

    /// End of the world-lock interval.
    let endDate: Date
}
