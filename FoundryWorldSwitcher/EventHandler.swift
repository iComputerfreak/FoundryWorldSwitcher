//
//  EventHandler.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM
import Logging
import Foundation
import JFUtils

/// Use `onInteractionCreate(_:)` for handling interactions.
struct EventHandler: GatewayEventHandler {
    let event: Gateway.Event
    let client: any DiscordClient
    let logger = Logger(label: "EventHandler")

    /// Handle Interactions.
    func onInteractionCreate(_ interaction: Interaction) async throws {
        /// You only have 3 second to respond, so it's better to send
        /// the response right away, and edit the response later.
        /// This will show a loading indicator to users.
        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource()
        ).guardSuccess()

        // TODO: Delete
        /// Delete this if you want. Just here so you notice the loading indicator :)
        try await Task.sleep(for: .seconds(1))

        /// Handle the interaction data
        switch interaction.data {
        case let .applicationCommand(applicationCommand):
            // Use the commands defined in main.swift
            guard let command = commands.first(where: \.name, equals: applicationCommand.name) else {
                throw DiscordCommandError.unknownCommand(commandName: applicationCommand.name)
            }
            try await command.handle(applicationCommand, interaction: interaction, client: client)
        default: break
        }
    }
}

