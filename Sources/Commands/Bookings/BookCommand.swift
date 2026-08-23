//
//  BookCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Logging

struct BookCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "book"
    let description = "Books a reservation or event"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    let requiresImmediateResponse = true

    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .subCommand,
            name: "reservation",
            description: "Opens a reservation booking form"
        ),
        .init(
            type: .subCommand,
            name: "event",
            description: "Opens an event booking form"
        )
    ]

    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        guard let subcommand = applicationCommand.options?.first,
              let kind = BookingCreationForm.Kind(rawValue: subcommand.name) else {
            throw DiscordCommandError.missingSubcommand
        }
        guard kind == .event || context.config.foundryFeaturesEnabled else {
            throw DiscordCommandError.foundryFeaturesDisabled
        }
        let worlds = context.config.foundryFeaturesEnabled ? try await PterodactylAPI.shared.worlds() : []
        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: BookingRenderer.creationModal(kind: kind, worlds: worlds)
        ).guardSuccess()
    }
}
