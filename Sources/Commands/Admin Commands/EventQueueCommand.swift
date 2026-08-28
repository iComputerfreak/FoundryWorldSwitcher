//
//  EventQueueCommand.swift
//
//
//  Created by Jonas Frey on 13.04.24.
//

import DiscordBM
import Foundation
import Logging

struct EventQueueCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: EventQueueCommand.self))
    let name = "eventqueue"
    let description = "Lists queued scheduler events for this server"
    let permissionsLevel: BotPermissionLevel = .admin
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        let events = await context.scheduler.events
        let localization = context.config.localization
        
        guard !events.isEmpty else {
            try await client.respond(
                token: interaction.token,
                message: localization.string("event_queue.empty", table: "Commands")
            )
            return
        }
        
        let eventList = events
            .sorted(by: { $0.dueDate < $1.dueDate })
            .map { event in
                "* \(DiscordUtils.timestamp(date: event.dueDate)): \(formattedEventType(event.eventType, localization: localization))"
            }
            .joined(separator: "\n")
        try await client.respond(
            token: interaction.token,
            message: localization.string("event_queue.list", table: "Commands", eventList)
        )
    }

    private func formattedEventType(_ eventType: SchedulerEventType, localization: LocalizationContext) -> String {
        switch eventType {
        case .consoleMessage(let message):
            return localization.string("event_queue.type.console_message", table: "Commands", message)
        case .lockWorldSwitching(let worldID):
            return localization.string("event_queue.type.lock_world", table: "Commands", worldID)
        case .unlockWorldSwitching:
            return localization.string("event_queue.type.unlock_world", table: "Commands")
        case .unlockManualWorldSwitching:
            return localization.string("event_queue.type.unlock_manual_world", table: "Commands")
        case .sendSessionReminder(let bookingID):
            return localization.string("event_queue.type.session_reminder", table: "Commands", bookingID.uuidString)
        case .sendSessionStartsReminder(let bookingID):
            return localization.string("event_queue.type.session_start_reminder", table: "Commands", bookingID.uuidString)
        case .removeBooking(let id):
            return localization.string("event_queue.type.remove_booking", table: "Commands", id.uuidString)
        case .closeDatePoll(let pollID):
            return localization.string("event_queue.type.close_date_poll", table: "Commands", pollID)
        case .sendDatePollReminder(let pollID, let userID):
            return localization.string(
                "event_queue.type.date_poll_user_reminder",
                table: "Commands",
                pollID,
                DiscordUtils.mention(id: userID)
            )
        case .sendOutstandingDatePollReminders(let pollID):
            return localization.string("event_queue.type.date_poll_reminders", table: "Commands", pollID)
        case .repeatDatePoll(let pollID):
            return localization.string("event_queue.type.repeat_date_poll", table: "Commands", pollID)
        case .syncDatePollMessage(let pollID):
            return localization.string("event_queue.type.sync_date_poll", table: "Commands", pollID)
        case .publishDatePoll(let pollID):
            return localization.string("event_queue.type.publish_date_poll", table: "Commands", pollID)
        }
    }
}
