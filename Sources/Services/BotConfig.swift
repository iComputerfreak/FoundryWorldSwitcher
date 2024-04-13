//
//  BotConfig.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import DiscordBM
import Foundation
import Logging

class BotConfig: Savable {
    static let logger = Logger(label: "BotConfig")
    static let dataPath = Utils.dataURL.appendingPathComponent("botConfig.json")
    static let shared: BotConfig = .loadOrDefault()
    
    // TODO: For some reason, we are not reading the file from disk correctly, the values are all default
    
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
    
    /// The time at which the booking starts in hours from midnight
    var bookingIntervalStartTime: Int {
        didSet { save() }
    }
    
    /// The time at which the booking ends in hours from midnight on the following day
    var bookingIntervalEndTime: Int {
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
        bookingIntervalStartTime: Int,
        bookingIntervalEndTime: Int,
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
        self.init(
            pterodactylHost: "",
            pterodactylServerID: "",
            sessionLength: 4 * GlobalConstants.secondsPerHour,
            bookingIntervalStartTime: 6,
            bookingIntervalEndTime: 5,
            sessionReminderTime: 1 * GlobalConstants.secondsPerDay,
            shouldNotifyAtSessionStart: true,
            sessionStartReminderTime: 5 * GlobalConstants.secondsPerMinute,
            reminderChannel: nil
        )
    }
}
