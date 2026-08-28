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
    /// Callers waiting for a single in-flight context initialization.
    private var contextWaiters: [GuildSnowflake: [CheckedContinuation<GuildContext, Error>]] = [:]

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
        if contextWaiters[guildID] != nil {
            return try await withCheckedThrowingContinuation { continuation in
                contextWaiters[guildID, default: []].append(continuation)
            }
        }
        contextWaiters[guildID] = []

        do {
            let context = try GuildContext(
                guildID: guildID,
                applicationOwnerID: applicationOwnerID,
                bookingConflicts: bookingConflicts
            )
            await context.synchronizeBookingConflicts()
            contexts[guildID] = context
            let waiters = contextWaiters.removeValue(forKey: guildID) ?? []
            for waiter in waiters { waiter.resume(returning: context) }
            return context
        } catch {
            let waiters = contextWaiters.removeValue(forKey: guildID) ?? []
            for waiter in waiters { waiter.resume(throwing: error) }
            throw error
        }
    }

    /// Prunes conflict records for guilds no longer served by this bot.
    func pruneBookingConflicts(guildIDs: Set<GuildSnowflake>) async {
        await bookingConflicts.prune(guildIDs: guildIDs)
    }

    /// Returns whether any loaded guild uses Foundry features.
    func hasFoundryFeaturesEnabled() -> Bool {
        contexts.values.contains { $0.config.foundryFeaturesEnabled }
    }

    /// Refreshes persisted booking schedules after startup resources become available.
    func refreshPinnedBookings() async {
        for context in contexts.values {
            do {
                try await context.bookings.updatePinnedBookings()
            } catch {
                Self.logger.warning("Failed to refresh pinned bookings for guild \(context.guildID): \(error)")
            }
        }
    }

    /// Resolves the global lock and its known expiry for Discord presence.
    func presenceLockState() async throws -> PresenceLockState {
        guard let lock = try WorldLockService.shared.currentLock() else {
            return .unlocked
        }
        if
            let guildID = lock.guildID,
            let bookingID = lock.bookingID,
            let context = contexts[guildID],
            let booking = await context.bookings.booking(id: bookingID)
        {
            return .locked(until: booking.bookingIntervalEndDate(using: context.config))
        }

        if lock.guildID == nil, lock.bookingID == nil {
            for context in contexts.values {
                let events = await context.scheduler.events
                if let unlockEvent = events.first(where: { event in
                    if case let .unlockManualWorldSwitching(acquiredAt) = event.eventType {
                        return acquiredAt == lock.acquiredAt
                    }
                    return false
                }) {
                    return .locked(until: unlockEvent.dueDate)
                }
            }
        }
        return .locked(until: nil)
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
        let contexts = self.contexts
        var errors: [Error] = []
        for (guildID, context) in contexts where self.contexts[guildID] === context {
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
