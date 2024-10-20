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

enum ConfigKey: String, CaseIterable {
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

struct PinnedBookingMessage: Codable {
    let channelID: ChannelSnowflake
    let messageID: MessageSnowflake
    let worldID: String?
    let role: RoleSnowflake?
}

class BotConfig: Savable {
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
    
    /// The time at which the booking ends in seconds from `bookingIntervalStartTime`
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
    
    var pinnedBookingMessages: [PinnedBookingMessage] {
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
    
    required convenience init() {
        self.init(
            pterodactylHost: Self.default.pterodactylHost,
            pterodactylServerID: Self.default.pterodactylServerID,
            sessionLength: Self.default.sessionLength,
            bookingIntervalStartTime: Self.default.bookingIntervalStartTime,
            bookingIntervalEndTime: Self.default.bookingIntervalEndTime,
            sessionReminderTime: Self.default.sessionReminderTime,
            shouldNotifyAtSessionStart: Self.default.shouldNotifyAtSessionStart,
            sessionStartReminderTime: Self.default.sessionStartReminderTime,
            reminderChannel: Self.default.reminderChannel,
            pinnedBookingMessages: Self.default.pinnedBookingMessages
        )
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.pterodactylHost = try container.decodeIfPresent(
            String.self,
            forKey: .pterodactylHost
        ) ?? Self.default.pterodactylHost
        self.pterodactylServerID = try container.decodeIfPresent(
            String.self,
            forKey: .pterodactylServerID
        ) ?? Self.default.pterodactylServerID
        self.sessionLength = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .sessionLength
        ) ?? Self.default.sessionLength
        self.bookingIntervalStartTime = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .bookingIntervalStartTime
        ) ?? Self.default.bookingIntervalStartTime
        self.bookingIntervalEndTime = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .bookingIntervalEndTime
        ) ?? Self.default.bookingIntervalEndTime
        self.sessionReminderTime = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .sessionReminderTime
        ) ?? Self.default.sessionReminderTime
        
        // Decode either from a JSON bool or a JSON integer
        // Note: Decoding from int is needed for compatibility with Pterodactyl, which seems to not be able to insert JSON bools into the config.
        do {
            self.shouldNotifyAtSessionStart = try container.decodeIfPresent(
                Bool.self,
                forKey: .shouldNotifyAtSessionStart
            ) ?? Self.default.shouldNotifyAtSessionStart
        } catch let boolError {
            // Try decoding as integer instead
            do {
                let intValue = try container.decodeIfPresent(Int.self, forKey: .shouldNotifyAtSessionStart)
                self.shouldNotifyAtSessionStart = intValue.flatMap { $0 == 1 } ?? Self.default.shouldNotifyAtSessionStart
            } catch let intError {
                // When both decoding as Bool, as well as decoding as Int fails, rethrow the original error
                throw boolError
            }
        }
        
        self.sessionStartReminderTime = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .sessionStartReminderTime
        ) ?? Self.default.sessionStartReminderTime
        self.reminderChannel = try container.decodeIfPresent(
            ChannelSnowflake.self,
            forKey: .reminderChannel
        ) ?? Self.default.reminderChannel
        self.pinnedBookingMessages = try container.decodeIfPresent(
            [PinnedBookingMessage].self,
            forKey: .pinnedBookingMessages
        ) ?? Self.default.pinnedBookingMessages
    }
}

extension BotConfig {
    static let `default`: BotConfig = .init(
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
}

// MARK: -  Config Discord Command
extension BotConfig {
    func value(for key: ConfigKey) -> String {
        switch key {
        case .pterodactylHost:
            return pterodactylHost
        case .pterodactylServerID:
            return pterodactylServerID
        case .sessionLength:
            return Utils.durationString(for: sessionLength)
        case .bookingIntervalStartTime:
            return Utils.timeString(for: bookingIntervalStartTime)
        case .bookingIntervalEndTime:
            return Utils.durationString(for: bookingIntervalEndTime)
        case .sessionReminderTime:
            return Utils.durationString(for: sessionReminderTime)
        case .shouldNotifyAtSessionStart:
            return shouldNotifyAtSessionStart ? "true" : "false"
        case .sessionStartReminderTime:
            return Utils.durationString(for: sessionStartReminderTime)
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
            let startOfDay = Calendar.current.startOfDay(for: .now)
            if let time = Utils.timeFormatter.date(from: value)?.timeIntervalSince(startOfDay) {
                bookingIntervalStartTime = time
            }
        
        case .bookingIntervalEndTime:
            guard let seconds = TimeInterval(value) else {
                throw DiscordCommandError.wrongDurationFormat(value)
            }
            bookingIntervalEndTime = seconds
        
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
    
    func resetValue(for key: ConfigKey) throws -> String {
        switch key {
        case .pterodactylHost:
            pterodactylHost = Self.default.pterodactylHost
        
        case .pterodactylServerID:
            pterodactylServerID = Self.default.pterodactylServerID
        
        case .sessionLength:
            sessionLength = Self.default.sessionLength
        
        case .bookingIntervalStartTime:
            bookingIntervalStartTime = Self.default.bookingIntervalStartTime
        
        case .bookingIntervalEndTime:
            bookingIntervalEndTime = Self.default.bookingIntervalEndTime
        
        case .sessionReminderTime:
            sessionReminderTime = Self.default.sessionReminderTime
        
        case .shouldNotifyAtSessionStart:
            shouldNotifyAtSessionStart = Self.default.shouldNotifyAtSessionStart
        
        case .sessionStartReminderTime:
            sessionStartReminderTime = Self.default.sessionStartReminderTime
        
        case .reminderChannel:
            reminderChannel = Self.default.reminderChannel
        }
        
        return value(for: key)
    }
}
