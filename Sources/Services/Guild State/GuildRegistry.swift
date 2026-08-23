import DiscordBM

/// Lazily creates and owns guild service contexts for this process.
actor GuildRegistry {
    /// Process-scoped owner granted administrator access in every context.
    private let applicationOwnerID: UserSnowflake?

    /// Shared booking conflict index for all contexts.
    private let bookingConflicts: GlobalBookingConflictService

    /// Loaded contexts keyed by guild ID.
    private var contexts: [GuildSnowflake: GuildContext] = [:]

    /// Creates a registry using the supplied application owner for every context.
    init(
        applicationOwnerID: UserSnowflake?,
        bookingConflicts: GlobalBookingConflictService = .init()
    ) {
        self.applicationOwnerID = applicationOwnerID
        self.bookingConflicts = bookingConflicts
    }

    /// Returns the context for `guildID`, loading its persisted state once.
    func context(for guildID: GuildSnowflake) async -> GuildContext {
        if let context = contexts[guildID] {
            return context
        }

        let context = GuildContext(
            guildID: guildID,
            applicationOwnerID: applicationOwnerID,
            bookingConflicts: bookingConflicts
        )
        contexts[guildID] = context
        await context.synchronizeBookingConflicts()
        return context
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
