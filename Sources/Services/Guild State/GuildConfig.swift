import DiscordBM
import Foundation
import Logging

/// Guild-local booking, reminder, and pinned-message configuration.
final class GuildConfig: BookingConfiguration {
    /// Logger for guild configuration persistence failures.
    private static let logger = Logger(label: "GuildConfig")

    /// File containing the persisted guild configuration.
    private let dataPath: URL

    /// Language used for this guild's user-facing output.
    private(set) var language: GuildLanguage

    /// Immutable localization snapshot for a guild operation.
    var localization: LocalizationContext { LocalizationContext(language: language) }

    /// The length of a session.
    private(set) var sessionLength: TimeInterval

    /// The time at which the booking starts in seconds from midnight.
    private(set) var bookingIntervalStartTime: TimeInterval

    /// The time at which the booking ends in seconds from `bookingIntervalStartTime`.
    private(set) var bookingIntervalEndTime: TimeInterval

    /// The default event time used when a booking form date omits a time.
    private(set) var defaultEventBookingTime: TimeInterval

    /// The time how much in advance the bot will remind players about a session.
    private(set) var sessionReminderTime: TimeInterval

    /// Whether the bot should notify players at the start of the session.
    private(set) var shouldNotifyAtSessionStart: Bool

    /// The time how much in advance the bot will remind players that the session is about to start.
    private(set) var sessionStartReminderTime: TimeInterval

    /// The channel where the bot will send reminders.
    private(set) var reminderChannel: ChannelSnowflake?

    /// Messages pinned by this guild that show its booking list.
    var pinnedBookingMessages: [PinnedBookingMessage] { didSet { save() } }

    /// Whether this guild may use Foundry worlds, bookings, locks, and related commands.
    private(set) var foundryFeaturesEnabled: Bool

    /// Default values used for new guild configuration files and resets.
    private static let defaultStored = GuildConfigStored(
        language: .english,
        sessionLength: 4 * GlobalConstants.secondsPerHour,
        bookingIntervalStartTime: 6 * GlobalConstants.secondsPerHour,
        bookingIntervalEndTime: 23 * GlobalConstants.secondsPerHour,
        defaultEventBookingTime: 19 * GlobalConstants.secondsPerHour,
        sessionReminderTime: 3 * GlobalConstants.secondsPerDay,
        shouldNotifyAtSessionStart: true,
        sessionStartReminderTime: 5 * GlobalConstants.secondsPerMinute,
        reminderChannel: nil,
        pinnedBookingMessages: [],
        foundryFeaturesEnabled: true
    )

    /// Loads configuration from `dataPath`, creating defaults when absent.
    init(dataPath: URL) throws {
        self.dataPath = dataPath
        let stored = try Self.load(from: dataPath) ?? Self.defaultStored
        language = stored.language ?? .english
        sessionLength = stored.sessionLength
        bookingIntervalStartTime = stored.bookingIntervalStartTime
        bookingIntervalEndTime = stored.bookingIntervalEndTime
        defaultEventBookingTime = stored.defaultEventBookingTime ?? 19 * GlobalConstants.secondsPerHour
        sessionReminderTime = stored.sessionReminderTime
        shouldNotifyAtSessionStart = stored.shouldNotifyAtSessionStart
        sessionStartReminderTime = stored.sessionStartReminderTime
        reminderChannel = stored.reminderChannel
        pinnedBookingMessages = stored.pinnedBookingMessages
        foundryFeaturesEnabled = stored.foundryFeaturesEnabled ?? true

        if !FileManager.default.fileExists(atPath: dataPath.path) {
            try Self.save(stored, to: dataPath)
        }
    }

    /// Returns the display value for a guild-scoped configuration key.
    func value(for key: ConfigKey) throws -> String {
        switch key {
        case .language:
            return language.rawValue
        case .sessionLength:
            return Utils.durationString(for: sessionLength)
        case .bookingIntervalStartTime:
            return Utils.timeString(for: bookingIntervalStartTime)
        case .bookingIntervalEndTime:
            return Utils.durationString(for: bookingIntervalEndTime)
        case .defaultEventBookingTime:
            return Utils.timeString(for: defaultEventBookingTime)
        case .sessionReminderTime:
            return Utils.durationString(for: sessionReminderTime)
        case .shouldNotifyAtSessionStart:
            return shouldNotifyAtSessionStart ? "true" : "false"
        case .sessionStartReminderTime:
            return Utils.durationString(for: sessionStartReminderTime)
        case .reminderChannel:
            return reminderChannel.map(DiscordUtils.mention(id:)) ?? "None"
        case .foundryFeaturesEnabled:
            return foundryFeaturesEnabled ? "true" : "false"
        case .pterodactylHost, .pterodactylServerID:
            throw DiscordCommandError.invalidConfigKey(key.rawValue)
        }
    }

    /// Validates and persists a new value for a guild-scoped configuration key.
    func setValue(_ value: String, for key: ConfigKey) throws {
        let original = stored()
        switch key {
        case .language:
            guard let newLanguage = GuildLanguage(configValue: value) else {
                throw DiscordCommandError.invalidConfigValue(key: key.rawValue, value: value)
            }
            try saveThrowing(language: newLanguage)
            language = newLanguage
            return
        case .sessionLength:
            sessionLength = try DurationParser.duration(from: value)
        case .bookingIntervalStartTime:
            guard let time = Utils.timeFormatter.date(from: value) else {
                throw DiscordCommandError.wrongTimeFormat(value, format: Utils.timeFormatter.dateFormat.uppercased())
            }
            bookingIntervalStartTime = Utils.timeIntervalSinceStartOfDay(for: time)
        case .bookingIntervalEndTime:
            guard let seconds = TimeInterval(value), seconds > 0 else {
                throw DiscordCommandError.wrongDurationFormat(value)
            }
            bookingIntervalEndTime = seconds
        case .defaultEventBookingTime:
            guard let time = Utils.timeFormatter.date(from: value) else {
                throw DiscordCommandError.wrongTimeFormat(value, format: Utils.timeFormatter.dateFormat.uppercased())
            }
            defaultEventBookingTime = Utils.timeIntervalSinceStartOfDay(for: time)
        case .sessionReminderTime:
            sessionReminderTime = try DurationParser.duration(from: value)
        case .shouldNotifyAtSessionStart:
            shouldNotifyAtSessionStart = value.lowercased() == "true"
        case .sessionStartReminderTime:
            sessionStartReminderTime = try DurationParser.duration(from: value)
        case .reminderChannel:
            reminderChannel = ChannelSnowflake(value)
        case .foundryFeaturesEnabled:
            guard ["true", "false"].contains(value.lowercased()) else {
                throw DiscordCommandError.invalidConfigKey(value)
            }
            foundryFeaturesEnabled = value.lowercased() == "true"
        case .pterodactylHost, .pterodactylServerID:
            throw DiscordCommandError.invalidConfigKey(key.rawValue)
        }
        do {
            try saveThrowing()
        } catch {
            restore(original)
            throw error
        }
    }

    /// Restores a guild-scoped configuration key to its default and returns it.
    func resetValue(for key: ConfigKey) throws -> String {
        let original = stored()
        switch key {
        case .language:
            let defaultLanguage = Self.defaultStored.language ?? .english
            try saveThrowing(language: defaultLanguage)
            language = defaultLanguage
            return try value(for: key)
        case .sessionLength:
            sessionLength = Self.defaultStored.sessionLength
        case .bookingIntervalStartTime:
            bookingIntervalStartTime = Self.defaultStored.bookingIntervalStartTime
        case .bookingIntervalEndTime:
            bookingIntervalEndTime = Self.defaultStored.bookingIntervalEndTime
        case .defaultEventBookingTime:
            defaultEventBookingTime = Self.defaultStored.defaultEventBookingTime ?? 19 * GlobalConstants.secondsPerHour
        case .sessionReminderTime:
            sessionReminderTime = Self.defaultStored.sessionReminderTime
        case .shouldNotifyAtSessionStart:
            shouldNotifyAtSessionStart = Self.defaultStored.shouldNotifyAtSessionStart
        case .sessionStartReminderTime:
            sessionStartReminderTime = Self.defaultStored.sessionStartReminderTime
        case .reminderChannel:
            reminderChannel = Self.defaultStored.reminderChannel
        case .foundryFeaturesEnabled:
            foundryFeaturesEnabled = Self.defaultStored.foundryFeaturesEnabled ?? true
        case .pterodactylHost, .pterodactylServerID:
            throw DiscordCommandError.invalidConfigKey(key.rawValue)
        }
        do {
            try saveThrowing()
        } catch {
            restore(original)
            throw error
        }
        return try value(for: key)
    }

    /// Persists all guild configuration values.
    private func save() {
        do {
            try saveThrowing()
        } catch {
            Self.logger.error("Failed to save guild config: \(error)")
        }
    }

    private func saveThrowing() throws {
        try saveThrowing(language: language)
    }

    private func saveThrowing(language: GuildLanguage) throws {
        try Self.save(stored(language: language), to: dataPath)
    }

    private func stored(language: GuildLanguage? = nil) -> GuildConfigStored {
        GuildConfigStored(
            language: language ?? self.language,
            sessionLength: sessionLength,
            bookingIntervalStartTime: bookingIntervalStartTime,
            bookingIntervalEndTime: bookingIntervalEndTime,
            defaultEventBookingTime: defaultEventBookingTime,
            sessionReminderTime: sessionReminderTime,
            shouldNotifyAtSessionStart: shouldNotifyAtSessionStart,
            sessionStartReminderTime: sessionStartReminderTime,
            reminderChannel: reminderChannel,
            pinnedBookingMessages: pinnedBookingMessages,
            foundryFeaturesEnabled: foundryFeaturesEnabled
        )
    }

    private func restore(_ stored: GuildConfigStored) {
        language = stored.language ?? .english
        sessionLength = stored.sessionLength
        bookingIntervalStartTime = stored.bookingIntervalStartTime
        bookingIntervalEndTime = stored.bookingIntervalEndTime
        defaultEventBookingTime = stored.defaultEventBookingTime ?? 19 * GlobalConstants.secondsPerHour
        sessionReminderTime = stored.sessionReminderTime
        shouldNotifyAtSessionStart = stored.shouldNotifyAtSessionStart
        sessionStartReminderTime = stored.sessionStartReminderTime
        reminderChannel = stored.reminderChannel
        foundryFeaturesEnabled = stored.foundryFeaturesEnabled ?? true
    }

    /// Decodes persisted guild configuration when its file exists and is valid.
    private static func load(from dataPath: URL) throws -> GuildConfigStored? {
        guard FileManager.default.fileExists(atPath: dataPath.path) else { return nil }
        do {
            return try JSONDecoder().decode(GuildConfigStored.self, from: Data(contentsOf: dataPath))
        } catch {
            throw PersistentStateError.load(dataPath, error)
        }
    }

    private static func save(_ stored: GuildConfigStored, to dataPath: URL) throws {
        do {
            try JSONEncoder().encode(stored).write(to: dataPath, options: .atomic)
        } catch {
            throw PersistentStateError.write(dataPath, error)
        }
    }
}
