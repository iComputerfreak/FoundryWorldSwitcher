import DiscordBM
import Foundation

/// Codable representation of guild booking configuration.
struct GuildConfigStored: Codable {
    /// Displayed duration of a session.
    var sessionLength: TimeInterval

    /// Seconds from local midnight when the booking interval begins.
    var bookingIntervalStartTime: TimeInterval

    /// Duration from interval start until the booking interval ends.
    var bookingIntervalEndTime: TimeInterval

    /// Lead time before a session for the regular reminder.
    var sessionReminderTime: TimeInterval

    /// Whether the bot should notify players at the session start.
    var shouldNotifyAtSessionStart: Bool

    /// Lead time before a session-start notification.
    var sessionStartReminderTime: TimeInterval

    /// Channel where the bot sends reminders.
    var reminderChannel: ChannelSnowflake?

    /// Guild booking messages to refresh after booking changes.
    var pinnedBookingMessages: [PinnedBookingMessage]
}
