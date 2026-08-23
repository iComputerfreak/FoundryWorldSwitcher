import DiscordBM
import Foundation
import Logging

/// Filesystem locations for state owned by one Discord guild.
struct GuildStatePaths {
    /// Directory containing all persisted state for the guild.
    let directory: URL

    /// Guild booking and reminder settings.
    let config: URL

    /// Guild user and role permission mappings.
    let permissions: URL

    /// Guild bookings.
    let bookings: URL

    /// Guild scheduler events.
    let events: URL

    /// Guild date polls.
    let datePolls: URL

    /// Creates the guild state directory and resolves all file paths.
    init(guildID: GuildSnowflake) {
        directory = Utils.dataURL
            .appendingPathComponent("guilds", isDirectory: true)
            .appendingPathComponent(guildID.rawValue, isDirectory: true)
        config = directory.appendingPathComponent("config.json")
        permissions = directory.appendingPathComponent("permissions.json")
        bookings = directory.appendingPathComponent("bookings.json")
        events = directory.appendingPathComponent("events.json")
        datePolls = directory.appendingPathComponent("date_polls.json")

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Logger(label: "GuildStatePaths").error("Failed to create guild state directory: \(error)")
        }
    }
}
