import DiscordBM
import Foundation
import Logging

/// Guild-local booking, reminder, and pinned-message configuration.
final class GuildConfig: BookingConfiguration {
    /// Logger for guild configuration persistence failures.
    private static let logger = Logger(label: "GuildConfig")

    /// File containing the persisted guild configuration.
    private let dataPath: URL

    /// The length of a session.
    var sessionLength: TimeInterval { didSet { save() } }

    /// The time at which the booking starts in seconds from midnight.
    var bookingIntervalStartTime: TimeInterval { didSet { save() } }

    /// The time at which the booking ends in seconds from `bookingIntervalStartTime`.
    var bookingIntervalEndTime: TimeInterval { didSet { save() } }

    /// The time how much in advance the bot will remind players about a session.
    var sessionReminderTime: TimeInterval { didSet { save() } }

    /// Whether the bot should notify players at the start of the session.
    var shouldNotifyAtSessionStart: Bool { didSet { save() } }

    /// The time how much in advance the bot will remind players that the session is about to start.
    var sessionStartReminderTime: TimeInterval { didSet { save() } }

    /// The channel where the bot will send reminders.
    var reminderChannel: ChannelSnowflake? { didSet { save() } }

    /// Messages pinned by this guild that show its booking list.
    var pinnedBookingMessages: [PinnedBookingMessage] { didSet { save() } }

    /// Default values used for new guild configuration files and resets.
    private static let defaultStored = GuildConfigStored(
        sessionLength: 4 * GlobalConstants.secondsPerHour,
        bookingIntervalStartTime: 6 * GlobalConstants.secondsPerHour,
        bookingIntervalEndTime: 23 * GlobalConstants.secondsPerHour,
        sessionReminderTime: 3 * GlobalConstants.secondsPerDay,
        shouldNotifyAtSessionStart: true,
        sessionStartReminderTime: 5 * GlobalConstants.secondsPerMinute,
        reminderChannel: nil,
        pinnedBookingMessages: []
    )

    /// Loads configuration from `dataPath`, creating defaults when absent.
    init(dataPath: URL) {
        self.dataPath = dataPath
        let stored = Self.load(from: dataPath) ?? Self.defaultStored
        sessionLength = stored.sessionLength
        bookingIntervalStartTime = stored.bookingIntervalStartTime
        bookingIntervalEndTime = stored.bookingIntervalEndTime
        sessionReminderTime = stored.sessionReminderTime
        shouldNotifyAtSessionStart = stored.shouldNotifyAtSessionStart
        sessionStartReminderTime = stored.sessionStartReminderTime
        reminderChannel = stored.reminderChannel
        pinnedBookingMessages = stored.pinnedBookingMessages

        if !FileManager.default.fileExists(atPath: dataPath.path) {
            save()
        }
    }

    /// Returns the display value for a guild-scoped configuration key.
    func value(for key: ConfigKey) throws -> String {
        switch key {
        case .sessionLength:
            return Utils.durationString(for: sessionLength)
        case .bookingIntervalStartTime:
            return Utils.timeString(for: bookingIntervalStartTime)
        case .bookingIntervalEndTime:
            return Utils.durationString(for: bookingIntervalEndTime)
        case .sessionReminderTime:
            return Utils.durationString(for: sessionReminderTime)
        case .shouldNotifyAtSessionStart:
            return shouldNotifyAtSessionStart ? "true" : "false"
        case .sessionStartReminderTime:
            return Utils.durationString(for: sessionStartReminderTime)
        case .reminderChannel:
            return reminderChannel.map(DiscordUtils.mention(id:)) ?? "None"
        case .pterodactylHost, .pterodactylServerID:
            throw DiscordCommandError.invalidConfigKey(key.rawValue)
        }
    }

    /// Validates and persists a new value for a guild-scoped configuration key.
    func setValue(_ value: String, for key: ConfigKey) throws {
        switch key {
        case .sessionLength:
            sessionLength = try DurationParser.duration(from: value)
        case .bookingIntervalStartTime:
            let startOfDay = Calendar.current.startOfDay(for: .now)
            guard let time = Utils.timeFormatter.date(from: value)?.timeIntervalSince(startOfDay) else {
                throw DiscordCommandError.wrongTimeFormat(value, format: Utils.timeFormatter.dateFormat.uppercased())
            }
            bookingIntervalStartTime = time
        case .bookingIntervalEndTime:
            guard let seconds = TimeInterval(value) else {
                throw DiscordCommandError.wrongDurationFormat(value)
            }
            bookingIntervalEndTime = seconds
        case .sessionReminderTime:
            sessionReminderTime = try DurationParser.duration(from: value)
        case .shouldNotifyAtSessionStart:
            shouldNotifyAtSessionStart = value.lowercased() == "true"
        case .sessionStartReminderTime:
            sessionStartReminderTime = try DurationParser.duration(from: value)
        case .reminderChannel:
            reminderChannel = ChannelSnowflake(value)
        case .pterodactylHost, .pterodactylServerID:
            throw DiscordCommandError.invalidConfigKey(key.rawValue)
        }
    }

    /// Restores a guild-scoped configuration key to its default and returns it.
    func resetValue(for key: ConfigKey) throws -> String {
        switch key {
        case .sessionLength:
            sessionLength = Self.defaultStored.sessionLength
        case .bookingIntervalStartTime:
            bookingIntervalStartTime = Self.defaultStored.bookingIntervalStartTime
        case .bookingIntervalEndTime:
            bookingIntervalEndTime = Self.defaultStored.bookingIntervalEndTime
        case .sessionReminderTime:
            sessionReminderTime = Self.defaultStored.sessionReminderTime
        case .shouldNotifyAtSessionStart:
            shouldNotifyAtSessionStart = Self.defaultStored.shouldNotifyAtSessionStart
        case .sessionStartReminderTime:
            sessionStartReminderTime = Self.defaultStored.sessionStartReminderTime
        case .reminderChannel:
            reminderChannel = Self.defaultStored.reminderChannel
        case .pterodactylHost, .pterodactylServerID:
            throw DiscordCommandError.invalidConfigKey(key.rawValue)
        }
        return try value(for: key)
    }

    /// Persists all guild configuration values.
    private func save() {
        do {
            let stored = GuildConfigStored(
                sessionLength: sessionLength,
                bookingIntervalStartTime: bookingIntervalStartTime,
                bookingIntervalEndTime: bookingIntervalEndTime,
                sessionReminderTime: sessionReminderTime,
                shouldNotifyAtSessionStart: shouldNotifyAtSessionStart,
                sessionStartReminderTime: sessionStartReminderTime,
                reminderChannel: reminderChannel,
                pinnedBookingMessages: pinnedBookingMessages
            )
            try JSONEncoder().encode(stored).write(to: dataPath)
        } catch {
            Self.logger.error("Failed to save guild config: \(error)")
        }
    }

    /// Decodes persisted guild configuration when its file exists and is valid.
    private static func load(from dataPath: URL) -> GuildConfigStored? {
        guard FileManager.default.fileExists(atPath: dataPath.path) else { return nil }
        do {
            return try JSONDecoder().decode(GuildConfigStored.self, from: Data(contentsOf: dataPath))
        } catch {
            logger.error("Failed to load guild config: \(error)")
            return nil
        }
    }
}
