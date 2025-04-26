//
//  EventBooking.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

struct EventBooking: Booking {
    let id: UUID
    var date: Date
    var author: UserSnowflake
    var worldID: String
    /// The group of players that are playing at this booking. If the booking is only for DM preparation, set this to `nil`.
    var campaignRoleSnowflake: RoleSnowflake
    /// The channel where the booking is taking place
    var location: ChannelSnowflake
    /// The topic of the booking (e.g., "Session 13")
    var topic: String
    var associatedEvents: [SchedulerEvent] = []
    var wasCancelled: Bool = false
    
    var sessionReminderTime: Date {
        date.addingTimeInterval(-BotConfig.shared.sessionReminderTime)
    }
    
    var sessionStartReminderTime: Date {
        date.addingTimeInterval(-BotConfig.shared.sessionStartReminderTime)
    }
    
    /// Creates a new booking with associated event information and a player role to notify before the event starts
    init(
        date: Date,
        author: UserSnowflake,
        worldID: String,
        campaignRoleSnowflake: RoleSnowflake,
        location: ChannelSnowflake,
        topic: String
    ) {
        self.id = UUID()
        self.date = date
        self.author = author
        self.worldID = worldID
        self.campaignRoleSnowflake = campaignRoleSnowflake
        self.location = location
        self.topic = topic
        self.associatedEvents = [
            SchedulerEvent(
                dueDate: bookingIntervalStartDate,
                eventType: .lockWorldSwitching(worldID: worldID)
            ),
            SchedulerEvent(
                dueDate: bookingIntervalEndDate,
                eventType: .unlockWorldSwitching
            ),
        ]
        // Only add the initial reminder, if it lies in the future
        if sessionReminderTime > .now {
            associatedEvents.append(
                SchedulerEvent(
                    dueDate: sessionReminderTime,
                    eventType: .sendSessionReminder(bookingID: id)
                )
            )
        }
        if BotConfig.shared.shouldNotifyAtSessionStart {
            associatedEvents.append(
                SchedulerEvent(
                    dueDate: sessionStartReminderTime,
                    eventType: .sendSessionStartsReminder(bookingID: id)
                )
            )
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.author = try container.decode(UserSnowflake.self, forKey: .author)
        self.worldID = try container.decode(String.self, forKey: .worldID)
        self.campaignRoleSnowflake = try container.decode(RoleSnowflake.self, forKey: .campaignRoleSnowflake)
        self.location = try container.decode(ChannelSnowflake.self, forKey: .location)
        self.topic = try container.decode(String.self, forKey: .topic)
        self.associatedEvents = try container.decode([SchedulerEvent].self, forKey: .associatedEvents)
        // This key was introduced in version 2.9.0 and may not exist on disk
        self.wasCancelled = try container.decodeIfPresent(Bool.self, forKey: .wasCancelled) ?? false
    }
}
