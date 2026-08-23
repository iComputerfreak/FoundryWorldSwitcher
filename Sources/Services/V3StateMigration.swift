import DiscordBM
import Foundation

/// Moves root guild state into the sole guild's V3 state directory.
enum V3StateMigration {
    private static let backupDirectory = Utils.dataURL
        .appendingPathComponent("migration-backups", isDirectory: true)
        .appendingPathComponent("v3", isDirectory: true)
    private static let stagingDirectory = Utils.dataURL
        .appendingPathComponent(".v3-migration-staging", isDirectory: true)

    /// Migrates root state only before `BotConfig.shared` can read or create its config file.
    static func runIfNeeded(guildIDs: [GuildSnowflake]) throws {
        let guildsDirectory = Utils.dataURL.appendingPathComponent("guilds", isDirectory: true)
        let rootConfigURL = Utils.dataURL.appendingPathComponent("botConfig.json")
        guard
            !FileManager.default.fileExists(atPath: guildsDirectory.path),
            FileManager.default.fileExists(atPath: rootConfigURL.path)
        else {
            return
        }
        try recoverIncompleteMigration()
        guard guildIDs.count == 1, let guildID = guildIDs.first else {
            throw MigrationError.requiresExactlyOneGuild(guildIDs.count)
        }

        guard !FileManager.default.fileExists(atPath: backupDirectory.path) else {
            throw MigrationError.backupExists(backupDirectory.path)
        }
        let staging = StagingPaths(guildID: guildID)
        let legacy = LegacyPaths()
        let worldLockPath = Utils.dataURL.appendingPathComponent("world-lock.json")
        guard
            !(FileManager.default.fileExists(atPath: legacy.worldLock.path)
                && FileManager.default.fileExists(atPath: worldLockPath.path))
        else {
            throw MigrationError.targetStateExists(worldLockPath.path)
        }

        let rootConfig = try LegacyRootConfig.load(from: rootConfigURL)
        let config = rootConfig.guildConfig
        let permissions = try (data(at: legacy.permissions, decoding: LegacyPermissions.self)
            ?? encoded(LegacyPermissions(userMap: [:], roleMap: [:])))
        let bookings = try (data(at: legacy.bookings, decoding: BookingList.self)
            ?? encoded(BookingList(bookings: [])))
        let events = try (data(at: legacy.events, decoding: [SchedulerEvent].self)
            ?? encoded([SchedulerEvent]()))
        let datePolls = try (data(at: legacy.datePolls, decoding: [DatePoll].self)
            ?? encoded([DatePoll]()))
        let conflicts = try conflictRecords(from: bookings, guildID: guildID, configuration: rootConfig)

        do {
            try FileManager.default.createDirectory(at: staging.guildDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: staging.globalDirectory, withIntermediateDirectories: true)
            try write(config, to: staging.targets.config, decoding: GuildConfigStored.self)
            try write(permissions, to: staging.targets.permissions, decoding: LegacyPermissions.self)
            try write(bookings, to: staging.targets.bookings, decoding: BookingList.self)
            try write(events, to: staging.targets.events, decoding: [SchedulerEvent].self)
            try write(datePolls, to: staging.targets.datePolls, decoding: [DatePoll].self)
            try write(conflicts, to: staging.conflicts, decoding: [GlobalBookingRecord].self)
            try write(GlobalBotConfig(rootConfig: rootConfig), to: staging.rootConfig, decoding: GlobalBotConfig.self)
            if FileManager.default.fileExists(atPath: legacy.worldLock.path) {
                try write(
                    WorldLockRecord(guildID: nil, bookingID: nil, acquiredAt: .now),
                    to: staging.worldLock,
                    decoding: WorldLockRecord.self
                )
            }

            let sources = legacy.guildStateFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
            try backup(sources + [rootConfigURL, staging.conflictTarget, worldLockPath], to: staging.backups)
            try FileManager.default.createDirectory(
                at: backupDirectory.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: staging.backups, to: backupDirectory)

            // This marker makes interrupted global replacement recoverable on the next boot.
            try Data().write(to: staging.globalWriteMarker)
            try replaceWithVerified(staging.conflicts, at: staging.conflictTarget, decoding: [GlobalBookingRecord].self)
            if FileManager.default.fileExists(atPath: staging.worldLock.path) {
                try replaceWithVerified(staging.worldLock, at: worldLockPath, decoding: WorldLockRecord.self)
            }
            try replaceWithVerified(staging.rootConfig, at: rootConfigURL, decoding: GlobalBotConfig.self)
            try FileManager.default.moveItem(at: staging.guildsDirectory, to: guildsDirectory)

            for source in sources {
                try? FileManager.default.removeItem(at: source)
            }
            try? FileManager.default.removeItem(at: staging.directory)
        } catch {
            try? restoreGlobalOutputs(from: backupDirectory)
            try? FileManager.default.removeItem(at: backupDirectory)
            try? FileManager.default.removeItem(at: staging.directory)
            throw error
        }
    }

    private static func conflictRecords(
        from bookingData: Data,
        guildID: GuildSnowflake,
        configuration: LegacyRootConfig
    ) throws -> Data {
        let bookings = try JSONDecoder().decode(BookingList.self, from: bookingData).allBookings
        let records = bookings.filter { !$0.wasCancelled }.map {
            GlobalBookingRecord(
                bookingID: $0.id,
                guildID: guildID,
                startDate: $0.bookingIntervalStartDate(using: configuration),
                endDate: $0.bookingIntervalEndDate(using: configuration)
            )
        }
        return try encoded(records)
    }

    private static func recoverIncompleteMigration() throws {
        guard FileManager.default.fileExists(atPath: stagingDirectory.path) else { return }
        let staging = StagingPaths(directory: stagingDirectory)
        if FileManager.default.fileExists(atPath: staging.globalWriteMarker.path) {
            let backups = FileManager.default.fileExists(atPath: backupDirectory.path) ? backupDirectory : staging.backups
            try restoreGlobalOutputs(from: backups)
            try? FileManager.default.removeItem(at: backupDirectory)
        } else {
            // Backup publication completed before global replacement. It belongs to this incomplete attempt.
            try? FileManager.default.removeItem(at: backupDirectory)
        }
        try FileManager.default.removeItem(at: stagingDirectory)
    }

    private static func backup(_ sources: [URL], to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for source in sources {
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let backup = directory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: backup)
            guard try Data(contentsOf: source) == Data(contentsOf: backup) else {
                throw MigrationError.backupVerificationFailed(source.lastPathComponent)
            }
        }
    }

    private static func replaceWithVerified<T: Decodable>(_ source: URL, at destination: URL, decoding type: T.Type) throws {
        try Data(contentsOf: source).write(to: destination, options: .atomic)
        _ = try JSONDecoder().decode(type, from: Data(contentsOf: destination))
    }

    private static func restoreGlobalOutputs(from backups: URL) throws {
        guard FileManager.default.fileExists(atPath: backups.path) else {
            throw MigrationError.backupMissing(backups.path)
        }
        try restore(
            Utils.dataURL.appendingPathComponent("botConfig.json"),
            from: backups.appendingPathComponent("botConfig.json"),
            decoding: LegacyRootConfig.self
        )
        try restore(
            Utils.dataURL.appendingPathComponent("booking_conflicts.json"),
            from: backups.appendingPathComponent("booking_conflicts.json"),
            decoding: [GlobalBookingRecord].self
        )
        try restore(
            Utils.dataURL.appendingPathComponent("world-lock.json"),
            from: backups.appendingPathComponent("world-lock.json"),
            decoding: WorldLockRecord.self
        )
    }

    private static func restore<T: Decodable>(_ destination: URL, from backup: URL, decoding type: T.Type) throws {
        guard FileManager.default.fileExists(atPath: backup.path) else {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            return
        }
        try Data(contentsOf: backup).write(to: destination, options: .atomic)
        _ = try JSONDecoder().decode(type, from: Data(contentsOf: destination))
    }

    private static func write<T: Decodable>(_ value: T, to url: URL, decoding type: T.Type) throws where T: Encodable {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw MigrationError.targetStateExists(url.path)
        }
        let data = try encoded(value)
        try data.write(to: url)
        _ = try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private static func write<T: Decodable>(_ data: Data, to url: URL, decoding type: T.Type) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw MigrationError.targetStateExists(url.path)
        }
        try data.write(to: url)
        _ = try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private static func data<T: Decodable>(at url: URL, decoding type: T.Type) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        _ = try JSONDecoder().decode(type, from: data)
        return data
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private struct LegacyPaths {
        let permissions = Utils.dataURL.appendingPathComponent("permissions.json")
        let bookings = Utils.dataURL.appendingPathComponent("bookings.json")
        let events = Utils.dataURL.appendingPathComponent("events.json")
        let datePolls = Utils.dataURL.appendingPathComponent("date_polls.json")
        let worldLock = Utils.dataURL.appendingPathComponent(".worldlock")

        var guildStateFiles: [URL] {
            [permissions, bookings, events, datePolls, worldLock]
        }
    }

    private struct TargetPaths {
        let directory: URL

        var config: URL { directory.appendingPathComponent("config.json") }
        var permissions: URL { directory.appendingPathComponent("permissions.json") }
        var bookings: URL { directory.appendingPathComponent("bookings.json") }
        var events: URL { directory.appendingPathComponent("events.json") }
        var datePolls: URL { directory.appendingPathComponent("date_polls.json") }
    }

    private struct StagingPaths {
        let directory: URL
        let guildsDirectory: URL
        let guildDirectory: URL
        let targets: TargetPaths
        let globalDirectory: URL
        let rootConfig: URL
        let conflicts: URL
        let worldLock: URL
        let backups: URL
        let globalWriteMarker: URL

        init(guildID: GuildSnowflake) {
            self.init(directory: stagingDirectory, guildID: guildID)
        }

        init(directory: URL, guildID: GuildSnowflake? = nil) {
            self.directory = directory
            guildsDirectory = directory.appendingPathComponent("guilds", isDirectory: true)
            guildDirectory = guildsDirectory.appendingPathComponent(guildID?.rawValue ?? "unknown", isDirectory: true)
            targets = TargetPaths(directory: guildDirectory)
            globalDirectory = directory.appendingPathComponent("global", isDirectory: true)
            rootConfig = globalDirectory.appendingPathComponent("botConfig.json")
            conflicts = globalDirectory.appendingPathComponent("booking_conflicts.json")
            worldLock = globalDirectory.appendingPathComponent("world-lock.json")
            backups = directory.appendingPathComponent("backups", isDirectory: true)
            globalWriteMarker = directory.appendingPathComponent("global-outputs-started")
        }

        var conflictTarget: URL { Utils.dataURL.appendingPathComponent("booking_conflicts.json") }
    }

    private struct LegacyPermissions: Codable {
        let userMap: [UserSnowflake: BotPermissionLevel]
        let roleMap: [RoleSnowflake: BotPermissionLevel]
    }

    private struct LegacyRootConfig: Codable, BookingConfiguration {
        private enum CodingKeys: String, CodingKey {
            case pterodactylHost
            case pterodactylServerID
            case sessionLength
            case bookingIntervalStartTime
            case bookingIntervalEndTime
            case sessionReminderTime
            case shouldNotifyAtSessionStart
            case sessionStartReminderTime
            case reminderChannel
            case pinnedBookingMessages
        }

        let pterodactylHost: String
        let pterodactylServerID: String
        let sessionLength: TimeInterval
        let bookingIntervalStartTime: TimeInterval
        let bookingIntervalEndTime: TimeInterval
        let sessionReminderTime: TimeInterval
        let shouldNotifyAtSessionStart: Bool
        let sessionStartReminderTime: TimeInterval
        let reminderChannel: ChannelSnowflake?
        let pinnedBookingMessages: [PinnedBookingMessage]

        static func load(from url: URL) throws -> Self {
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        }

        var guildConfig: GuildConfigStored {
            .init(
                sessionLength: sessionLength,
                bookingIntervalStartTime: bookingIntervalStartTime,
                bookingIntervalEndTime: bookingIntervalEndTime,
                sessionReminderTime: sessionReminderTime,
                shouldNotifyAtSessionStart: shouldNotifyAtSessionStart,
                sessionStartReminderTime: sessionStartReminderTime,
                reminderChannel: reminderChannel,
                pinnedBookingMessages: pinnedBookingMessages
            )
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            pterodactylHost = try container.decodeIfPresent(String.self, forKey: .pterodactylHost) ?? ""
            pterodactylServerID = try container.decodeIfPresent(String.self, forKey: .pterodactylServerID) ?? ""
            sessionLength = try container.decodeIfPresent(TimeInterval.self, forKey: .sessionLength) ?? Self.default.sessionLength
            bookingIntervalStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .bookingIntervalStartTime) ?? Self.default.bookingIntervalStartTime
            bookingIntervalEndTime = try container.decodeIfPresent(TimeInterval.self, forKey: .bookingIntervalEndTime) ?? Self.default.bookingIntervalEndTime
            sessionReminderTime = try container.decodeIfPresent(TimeInterval.self, forKey: .sessionReminderTime) ?? Self.default.sessionReminderTime
            shouldNotifyAtSessionStart = try Self.bool(forKey: .shouldNotifyAtSessionStart, in: container)
            sessionStartReminderTime = try container.decodeIfPresent(TimeInterval.self, forKey: .sessionStartReminderTime) ?? Self.default.sessionStartReminderTime
            reminderChannel = try Self.channel(forKey: .reminderChannel, in: container)
            pinnedBookingMessages = try container.decodeIfPresent([PinnedBookingMessage].self, forKey: .pinnedBookingMessages) ?? []
        }

        init(
            pterodactylHost: String,
            pterodactylServerID: String,
            sessionLength: TimeInterval,
            bookingIntervalStartTime: TimeInterval,
            bookingIntervalEndTime: TimeInterval,
            sessionReminderTime: TimeInterval,
            shouldNotifyAtSessionStart: Bool,
            sessionStartReminderTime: TimeInterval,
            reminderChannel: ChannelSnowflake?,
            pinnedBookingMessages: [PinnedBookingMessage]
        ) {
            self.pterodactylHost = pterodactylHost
            self.pterodactylServerID = pterodactylServerID
            self.sessionLength = sessionLength
            self.bookingIntervalStartTime = bookingIntervalStartTime
            self.bookingIntervalEndTime = bookingIntervalEndTime
            self.sessionReminderTime = sessionReminderTime
            self.shouldNotifyAtSessionStart = shouldNotifyAtSessionStart
            self.sessionStartReminderTime = sessionStartReminderTime
            self.reminderChannel = reminderChannel
            self.pinnedBookingMessages = pinnedBookingMessages
        }

        private static let `default` = Self(
            pterodactylHost: "",
            pterodactylServerID: "",
            sessionLength: 4 * GlobalConstants.secondsPerHour,
            bookingIntervalStartTime: 6 * GlobalConstants.secondsPerHour,
            bookingIntervalEndTime: 23 * GlobalConstants.secondsPerHour,
            sessionReminderTime: 3 * GlobalConstants.secondsPerDay,
            shouldNotifyAtSessionStart: true,
            sessionStartReminderTime: 5 * GlobalConstants.secondsPerMinute,
            reminderChannel: nil,
            pinnedBookingMessages: []
        )

        private static func bool(
            forKey key: CodingKeys,
            in container: KeyedDecodingContainer<CodingKeys>
        ) throws -> Bool {
            if let value = try? container.decode(Bool.self, forKey: key) { return value }
            if let value = try? container.decode(Int.self, forKey: key) { return value == 1 }
            return Self.default.shouldNotifyAtSessionStart
        }

        private static func channel(
            forKey key: CodingKeys,
            in container: KeyedDecodingContainer<CodingKeys>
        ) throws -> ChannelSnowflake? {
            if let value = try? container.decodeIfPresent(ChannelSnowflake.self, forKey: key) { return value }
            if let value = try? container.decode(Int.self, forKey: key) { return ChannelSnowflake("\(value)") }
            return nil
        }
    }

    private struct GlobalBotConfig: Codable {
        let pterodactylHost: String
        let pterodactylServerID: String

        init(rootConfig: LegacyRootConfig) {
            pterodactylHost = rootConfig.pterodactylHost
            pterodactylServerID = rootConfig.pterodactylServerID
        }
    }

    private enum MigrationError: LocalizedError {
        case requiresExactlyOneGuild(Int)
        case targetStateExists(String)
        case backupExists(String)
        case backupVerificationFailed(String)
        case backupMissing(String)

        var errorDescription: String? {
            switch self {
            case let .requiresExactlyOneGuild(count):
                return "V3 migration requires exactly one guild, found \(count)."
            case let .targetStateExists(path):
                return "V3 migration will not overwrite existing state at \(path)."
            case let .backupExists(path):
                return "V3 migration backup already exists at \(path)."
            case let .backupVerificationFailed(name):
                return "V3 migration could not verify backup for \(name)."
            case let .backupMissing(path):
                return "V3 migration backup is missing at \(path)."
            }
        }
    }
}
