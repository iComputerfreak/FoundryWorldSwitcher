import DiscordBM

/// Instance-scoped services and state for one Discord guild.
final class GuildContext {
    /// Guild served by this context.
    let guildID: GuildSnowflake

    /// Filesystem locations for the guild's persisted state.
    let paths: GuildStatePaths

    /// Guild booking and reminder settings.
    let config: GuildConfig

    /// Guild user and role permission mappings.
    let permissions: Permissions

    /// Guild scheduler.
    let scheduler: Scheduler

    /// Guild booking service.
    let bookings: BookingsService

    /// Guild date-poll service.
    let datePolls: DatePollsService

    /// Guild preferences for automatic date-poll reminders.
    let datePollReminderPreferences: DatePollReminderPreferences

    /// Shared global booking-conflict service.
    let bookingConflicts: GlobalBookingConflictService

    /// Creates all services for `guildID` using the process-scoped application owner.
    init(
        guildID: GuildSnowflake,
        applicationOwnerID: UserSnowflake?,
        bookingConflicts: GlobalBookingConflictService
    ) throws {
        self.guildID = guildID
        self.paths = try .init(guildID: guildID)
        self.config = try .init(dataPath: paths.config)
        self.permissions = try .init(dataPath: paths.permissions, applicationOwnerID: applicationOwnerID)
        self.scheduler = try .init(dataPath: paths.events)
        self.bookingConflicts = bookingConflicts
        self.bookings = try .init(
            scheduler: scheduler,
            dataPath: paths.bookings,
            configuration: config,
            pinnedMessagesConfiguration: config,
            guildID: guildID,
            bookingConflicts: bookingConflicts
        )
        self.datePolls = try .init(scheduler: scheduler, dataPath: paths.datePolls, permissions: permissions)
        self.datePollReminderPreferences = try .init(dataPath: paths.datePollReminderPreferences)
    }

    /// Rebuilds this guild's entries in the shared booking-conflict index.
    func synchronizeBookingConflicts() async {
        await bookingConflicts.replaceBookings(
            for: guildID,
            bookings: await bookings.allBookings,
            configuration: config
        )
        await datePolls.restoreScheduling()
    }
}
