import DiscordBM
import Logging

/// Lazily creates and owns guild service contexts for this process.
actor GuildRegistry {
    private static let logger = Logger(label: "GuildRegistry")

    /// Process-scoped owner granted administrator access in every context.
    private let applicationOwnerID: UserSnowflake?

    /// Shared booking conflict index for all contexts.
    private let bookingConflicts: GlobalBookingConflictService

    /// Loaded contexts keyed by guild ID.
    private var contexts: [GuildSnowflake: GuildContext] = [:]

    /// Creates a registry using the supplied application owner for every context.
    init(applicationOwnerID: UserSnowflake?) throws {
        self.applicationOwnerID = applicationOwnerID
        self.bookingConflicts = try .init()
    }

    init(applicationOwnerID: UserSnowflake?, bookingConflicts: GlobalBookingConflictService) {
        self.applicationOwnerID = applicationOwnerID
        self.bookingConflicts = bookingConflicts
    }

    /// Returns the context for `guildID`, loading its persisted state once.
    func context(for guildID: GuildSnowflake) async throws -> GuildContext {
        if let context = contexts[guildID] {
            return context
        }

        let context = try GuildContext(
            guildID: guildID,
            applicationOwnerID: applicationOwnerID,
            bookingConflicts: bookingConflicts
        )
        await context.synchronizeBookingConflicts()
        contexts[guildID] = context
        return context
    }

    /// Prunes conflict records for guilds no longer served by this bot.
    func pruneBookingConflicts(guildIDs: Set<GuildSnowflake>) async {
        await bookingConflicts.prune(guildIDs: guildIDs)
    }

    /// Returns whether any loaded guild uses Foundry features.
    func hasFoundryFeaturesEnabled() -> Bool {
        contexts.values.contains { $0.config.foundryFeaturesEnabled }
    }

    /// Stops serving a guild after the bot is removed and releases its global resources.
    func removeContext(for guildID: GuildSnowflake) async {
        contexts.removeValue(forKey: guildID)
        await bookingConflicts.removeAll(for: guildID)
        do {
            try WorldLockService.shared.unlockWorldSwitching(for: guildID)
        } catch {
            Self.logger.error("Failed to release world lock for removed guild \(guildID): \(error)")
        }
    }

    /// Returns the sole loaded context containing a date poll with `pollID`.
    func context(forDatePollID pollID: String) async throws -> GuildContext {
        var matches: [GuildContext] = []
        for context in contexts.values {
            if (try? await context.datePolls.poll(id: pollID)) != nil {
                matches.append(context)
            }
        }
        guard matches.count == 1, let context = matches.first else {
            throw DatePollError.notFound(pollID)
        }
        return context
    }

    /// Runs due scheduler events for every loaded guild context.
    func updateSchedulers() async throws {
        let contexts = Array(contexts.values)
        var errors: [Error] = []
        for context in contexts {
            do {
                try await context.scheduler.update(in: context)
            } catch {
                errors.append(error)
            }
        }
        if errors.count > 1 {
            throw CompoundError(errors: errors)
        } else if let error = errors.first {
            throw error
        }
    }
}
