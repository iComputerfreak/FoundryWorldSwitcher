//
//  ConfigCommand.swift
//
//
//  Created by Jonas Frey on 13.04.24.
//

import DiscordBM
import Foundation
import Logging

struct ConfigCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "config"
    let description = "Configures the bot"
    let permissionsLevel: BotPermissionLevel = .admin
    
    // /config show [key]
    // /config set <key> <value>
    // /config reset <key>
    var options: [ApplicationCommand.Option]? = [
        .init(
            type: .subCommand,
            name: "show",
            description: "Shows the current configuration",
            options: [
                .init(
                    type: .string,
                    name: "key",
                    description: "The key of the configuration to show",
                    required: false
                )
            ]
        ),
        .init(
            type: .subCommand,
            name: "set",
            description: "Sets a configuration value",
            options: [
                .init(
                    type: .string,
                    name: "key",
                    description: "The key of the configuration to set",
                    required: true
                ),
                .init(
                    type: .string,
                    name: "value",
                    description: "The value to set",
                    required: true
                )
            ]
        ),
        .init(
            type: .subCommand,
            name: "reset",
            description: "Resets a configuration value to its default value",
            options: [
                .init(
                    type: .string,
                    name: "key",
                    description: "The key of the configuration to reset",
                    required: true
                )
            ]
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        try await client.respond(
            token: interaction.token,
            message: "Hello, I am listening!"
        )
    }
    
    private func handleShowKey(_ key: String, interaction: Interaction, client: any DiscordClient) {
//        let value = BotConfig.shared[key]
    }
}
