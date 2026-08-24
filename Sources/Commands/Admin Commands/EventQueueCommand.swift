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
        
        guard !events.isEmpty else {
            try await client.respond(
                token: interaction.token,
                message: "There are currently no events in the queue."
            )
            return
        }
        
        let eventList = events
            .sorted(by: { $0.dueDate < $1.dueDate })
            .map { event in
                "* \(DiscordUtils.timestamp(date: event.dueDate)): \(event.eventType)"
            }
            .joined(separator: "\n")
        try await client.respond(
            token: interaction.token,
            message: "The following events are currently in the event queue:\n\(eventList)"
        )
    }
}
