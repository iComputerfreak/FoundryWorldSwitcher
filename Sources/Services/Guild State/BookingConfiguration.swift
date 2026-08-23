import Foundation

/// Timing settings used to derive a booking's session and world-lock intervals.
protocol BookingConfiguration {
    /// Displayed duration of a session.
    var sessionLength: TimeInterval { get }

    /// Seconds from local midnight when the booking interval begins.
    var bookingIntervalStartTime: TimeInterval { get }

    /// Duration from interval start until the booking interval ends.
    var bookingIntervalEndTime: TimeInterval { get }

    /// Lead time before a session for the regular reminder.
    var sessionReminderTime: TimeInterval { get }

    /// Whether to notify players at the session start.
    var shouldNotifyAtSessionStart: Bool { get }

    /// Lead time before a session-start notification.
    var sessionStartReminderTime: TimeInterval { get }
}
