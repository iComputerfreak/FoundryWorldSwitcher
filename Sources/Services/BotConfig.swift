//
//  BotConfig.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import DiscordBM
import Foundation
import Logging
import RegexBuilder

enum ConfigKey: String {
    case pterodactylHost
    case pterodactylServerID
    case sessionLength
    case bookingIntervalStartTime
    case bookingIntervalEndTime
    case sessionReminderTime
    case shouldNotifyAtSessionStart
    case sessionStartReminderTime
    case reminderChannel
}

class BotConfig: Savable {
    /// A date components formatter for durations
    static let dateComponentsFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.zeroFormattingBehavior = .dropAll
        f.allowedUnits = [.hour, .minute]
        return f
    }()
    
    /// A date formatter for time strings
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    static let logger = Logger(label: "BotConfig")
    static let dataPath = Utils.dataURL.appendingPathComponent("botConfig.json")
    static let shared: BotConfig = .loadOrDefault()
    
    /// The hostname of the Pterodactyl panel
    var pterodactylHost: String {
        didSet { save() }
    }
    
    /// The ID of the server on the Pterodactyl panel
    var pterodactylServerID: String {
        didSet { save() }
    }
    
    /// The length of a session
    var sessionLength: TimeInterval {
        didSet { save() }
    }
    
    /// The time at which the booking starts in seconds from midnight
    var bookingIntervalStartTime: TimeInterval {
        didSet { save() }
    }
    
    /// The time at which the booking ends in seconds from midnight on the following day
    var bookingIntervalEndTime: TimeInterval {
        didSet { save() }
    }
    
    /// The time how much in advance the bot will remind players about a session
    var sessionReminderTime: TimeInterval {
        didSet { save() }
    }
    
    /// Whether the bot should notify players at the start of the session
    var shouldNotifyAtSessionStart: Bool {
        didSet { save() }
    }
    
    /// The time how much in advance the bot will remind players that the session is about to start
    var sessionStartReminderTime: TimeInterval {
        didSet { save() }
    }
    
    /// The channel where the bot will send reminders
    var reminderChannel: ChannelSnowflake? {
        didSet { save() }
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
        reminderChannel: ChannelSnowflake?
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
    }
    
    required convenience init() {
        // Default config values
        self.init(
            pterodactylHost: "",
            pterodactylServerID: "",
            sessionLength: 4 * GlobalConstants.secondsPerHour,
            bookingIntervalStartTime: 6 * GlobalConstants.secondsPerHour,
            bookingIntervalEndTime: 5 * GlobalConstants.secondsPerHour,
            sessionReminderTime: 3 * GlobalConstants.secondsPerDay,
            shouldNotifyAtSessionStart: true,
            sessionStartReminderTime: 5 * GlobalConstants.secondsPerMinute,
            reminderChannel: nil
        )
    }
}

// MARK: -  Discord Command
extension BotConfig {
    /// Returns a duration string for a given time interval
    static func durationString(for duration: TimeInterval) -> String {
        let reference = Date(timeIntervalSinceReferenceDate: 0)
        return dateComponentsFormatter.string(from: reference, to: reference.addingTimeInterval(duration)) ?? ""
    }
    
    /// Returns a time string for a given time in seconds from midnight
    static func timeString(for timeFromMidnight: TimeInterval) -> String {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let time = startOfDay.addingTimeInterval(timeFromMidnight)
        return timeFormatter.string(from: time)
    }
    
    func value(for key: ConfigKey) -> String {
        switch key {
        case .pterodactylHost:
            return pterodactylHost
        case .pterodactylServerID:
            return pterodactylServerID
        case .sessionLength:
            return Self.durationString(for: sessionLength)
        case .bookingIntervalStartTime:
            return Self.timeString(for: bookingIntervalStartTime)
        case .bookingIntervalEndTime:
            return Self.timeString(for: bookingIntervalEndTime)
        case .sessionReminderTime:
            return Self.durationString(for: sessionReminderTime)
        case .shouldNotifyAtSessionStart:
            return shouldNotifyAtSessionStart ? "true" : "false"
        case .sessionStartReminderTime:
            return Self.durationString(for: sessionStartReminderTime)
        case .reminderChannel:
            return reminderChannel.map(DiscordUtils.mention(id:)) ?? "None"
        }
    }
    
    func setValue(_ value: String, for key: ConfigKey) throws {
        switch key {
        case .pterodactylHost:
            pterodactylHost = value
        
        case .pterodactylServerID:
            pterodactylServerID = value
        
        case .sessionLength:
            sessionLength = try DurationParser.duration(from: value)
        
        case .bookingIntervalStartTime:
            if let time = Self.timeFormatter.date(from: value)?.timeIntervalSince(Calendar.current.startOfDay(for: .now)) {
                bookingIntervalStartTime = time
            }
        
        case .bookingIntervalEndTime:
            if let time = Self.timeFormatter.date(from: value)?.timeIntervalSince(Calendar.current.startOfDay(for: .now)) {
                bookingIntervalEndTime = time
            }
        
        case .sessionReminderTime:
            sessionReminderTime = try DurationParser.duration(from: value)
        
        case .shouldNotifyAtSessionStart:
            shouldNotifyAtSessionStart = value.lowercased() == "true"
        
        case .sessionStartReminderTime:
            sessionStartReminderTime = try DurationParser.duration(from: value)
        
        case .reminderChannel:
            reminderChannel = ChannelSnowflake(value)
        }
    }
}
