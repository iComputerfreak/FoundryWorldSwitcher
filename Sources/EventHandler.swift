//
//  EventHandler.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM
import Logging
import Foundation

/// Use `onInteractionCreate(_:)` for handling interactions.
struct EventHandler: GatewayEventHandler {
    let event: Gateway.Event
    let client: any DiscordClient
    let logger = Logger(label: "EventHandler")
    let permissionsHandler: PermissionsHandler

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

        /// Handle the interaction data
        switch interaction.data {
        case let .applicationCommand(applicationCommand):
            // Use the commands defined in main.swift
            do {
                guard let command = commands.first(where: { $0.name == applicationCommand.name }) else {
                    throw DiscordCommandError.unknownCommand(commandName: applicationCommand.name)
                }
                guard let member = interaction.member else {
                    throw DiscordCommandError.noMember
                }
                guard let username = member.user?.username else {
                    throw DiscordCommandError.noUser
                }
                do {
                    // Check user permissions
                    try permissionsHandler.checkAuthorization(of: member, for: command)
                    try await command.handle(applicationCommand, interaction: interaction, client: client)
                } catch DiscordCommandError.unauthorized {
                    logger.warning("User \(username) has been denied of executing command \(command.name) due to insufficient permissions.")
                    try await client.respond(
                        token: interaction.token,
                        message: "You need at least permission level `\(command.permissionsLevel)` to execute this command."
                    )
                } catch DiscordCommandError.missingArgument(argumentName: let argName) {
                    try await client.respond(
                        token: interaction.token,
                        message: "Error: You need to specify the argument `\(argName)`."
                    )
                }
            } catch {
                logger.error("Error handling command /\(applicationCommand.name): \(error)")
                try await client.respond(
                    token: interaction.token,
                    message: "There was an error running your command. Please contact an administrator for more information."
                )
            }
        default: break
        }
    }
}

