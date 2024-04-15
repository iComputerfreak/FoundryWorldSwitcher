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
        // We handle "/config show" separately, as it's the only command that does not need a `key` argument
        if
            let showCommand = applicationCommand.option(named: "show"),
            showCommand.option(named: "key")?.value == nil
        {
            try await client.respond(token: interaction.token, payload: createFullConfigPayload())
            return
        }
        
        func respond(_ payload: Payloads.EditWebhookMessage) async throws {
            try await client.respond(token: interaction.token, payload: payload)
        }
        
        func respond(_ message: String) async throws {
            try await respond(.init(content: message))
        }
        
        func value(for stringKey: String) throws -> String {
            guard let configKey = ConfigKey(rawValue: stringKey) else {
                throw DiscordCommandError.invalidConfigKey(stringKey)
            }
            return BotConfig.shared.value(for: configKey)
        }
        
        if let showCommand = applicationCommand.option(named: "show") {
            if let keyString = showCommand.option(named: "key")?.value?.stringValue {
                try await respond("The value of `\(keyString)` is `\(value(for: keyString))`")
            } else {
                try await respond(createFullConfigPayload())
            }
        } else if let setCommand = applicationCommand.option(named: "set") {
            let keyString = try setCommand.requireOption(named: "key").requireString()
            let valueString = try setCommand.requireOption(named: "value").requireString()
            guard let configKey = ConfigKey(rawValue: keyString) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            try BotConfig.shared.setValue(valueString, for: configKey)
            try await respond("The value `\(keyString)` was updated to `\(valueString)`.")
        } else if let resetCommand = applicationCommand.option(named: "reset") {
            let keyString = try resetCommand.requireOption(named: "key").requireString()
            guard let configKey = ConfigKey(rawValue: keyString) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            let newValue = try BotConfig.shared.resetValue(for: configKey)
            try await respond("The value `\(keyString)` was reset to its default value `\(newValue)`.")
        } else {
            throw DiscordCommandError.missingSubcommand
        }
    }
    
    private func createFullConfigPayload() -> Payloads.EditWebhookMessage {
        let embed = Embed(
            title: "Bot Configuration",
            description: "Here are the current configuration values",
            fields: ConfigKey.allCases.map { key in
                Embed.Field(
                    name: key.rawValue,
                    value: BotConfig.shared.value(for: key),
                    inline: true
                )
            }
        )
        return .init(embeds: [embed])
    }
    
    private func handleShowKey(_ key: String, interaction: Interaction, client: any DiscordClient) {
//        let value = BotConfig.shared[key]
    }
}
