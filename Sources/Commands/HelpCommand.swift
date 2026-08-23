//
//  HelpCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation
import DiscordBM
import Logging

struct HelpCommand: DiscordCommand {
    var logger: Logger = .init(label: String(describing: Self.self))
    let name = "help"
    let description = "Lists commands available in this server"
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        let commands = DiscordCommands.commands
            .filter { context.config.foundryFeaturesEnabled || !$0.requiresFoundryFeatures }
            .sorted { $0.name < $1.name }
        let commandList = commands.map { "- `/\($0.name)` - \($0.description)" }.joined(separator: "\n")
        try await client.respond(
            token: interaction.token,
            message: """
            ## Available commands
            \(commandList)

            *Bot version: \(version)*
            """
        )
    }
}
