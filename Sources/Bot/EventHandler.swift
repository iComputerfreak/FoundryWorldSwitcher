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
    let guildRegistry: GuildRegistry

    /// Handle Interactions.
    func onInteractionCreate(_ interaction: Interaction) async throws {
        guard let interactionData = interaction.data else { return }
        switch interactionData {
        case let .applicationCommand(applicationCommand):
            try await handleApplicationCommand(applicationCommand, interaction: interaction)
        case let .messageComponent(component):
            try await DatePollComponentHandler(client: client, guildRegistry: guildRegistry).handle(component, interaction: interaction)
        case let .modalSubmit(modal):
            if BookingCreationForm.kind(from: modal.custom_id) != nil {
                try await BookingModalHandler(client: client, guildRegistry: guildRegistry).handle(modal, interaction: interaction)
            } else {
                try await DatePollModalHandler(client: client, guildRegistry: guildRegistry).handle(modal, interaction: interaction)
            }
        }
    }

    func onGuildDelete(_ guild: UnavailableGuild) async throws {
        guard guild.unavailable != true else { return }
        await guildRegistry.removeContext(for: guild.id)
    }

    private func handleApplicationCommand(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction
    ) async throws {
        var deferredResponse = false
        do {
            guard let command = DiscordCommands.commands.first(where: { $0.name == applicationCommand.name }) else {
                throw DiscordCommandError.unknownCommand(commandName: applicationCommand.name)
            }
            let requiresImmediateResponse = command.requiresImmediateResponse
            if !requiresImmediateResponse {
                // Most commands may take longer than Discord's response window.
                try await client.createInteractionResponse(
                    id: interaction.id,
                    token: interaction.token,
                    payload: .deferredChannelMessageWithSource()
                ).guardSuccess()
                deferredResponse = true
            }
            guard let guildID = interaction.guild_id else {
                throw DiscordCommandError.noGuild
            }
            let context = try await guildRegistry.context(for: guildID)
            guard let member = interaction.member else {
                throw DiscordCommandError.noMember
            }
            guard let username = member.user?.username else {
                throw DiscordCommandError.noUser
            }
            do {
                // Check user permissions
                try permissionsHandler.checkAuthorization(of: member, for: command, in: context)
                try await command.handle(applicationCommand, interaction: interaction, context: context, client: client)
            } catch DiscordCommandError.unauthorized {
                logger.warning("User \(username) has been denied of executing command \(command.name) due to insufficient permissions.")
                try await respond(
                    to: interaction,
                    message: "You need at least permission level `\(command.permissionsLevel)` to execute this command.",
                    immediately: requiresImmediateResponse
                )
            } catch DiscordCommandError.missingArgument(argumentName: let argName) {
                try await respond(
                    to: interaction,
                    message: "Error: You need to specify the argument `\(argName)`.",
                    immediately: requiresImmediateResponse
                )
            }
        } catch {
            logger.error("Error handling command /\(applicationCommand.name): \(error)")
            try await respond(
                to: interaction,
                message: "There was an error running your command:\n\(error.localizedDescription)",
                immediately: !deferredResponse
            )
        }
    }

    private func respond(to interaction: Interaction, message: String, immediately: Bool) async throws {
        if immediately {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(content: message, flags: [.ephemeral]))
            ).guardSuccess()
        } else {
            try await client.respond(token: interaction.token, message: message)
        }
    }
}
