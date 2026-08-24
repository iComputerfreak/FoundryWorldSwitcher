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
    let description = "Views or changes this server's booking, reminder, and Foundry-feature settings"
    let permissionsLevel: BotPermissionLevel = .admin
    private static let guildConfigKeys = ConfigKey.allCases.filter {
        $0 != .pterodactylHost && $0 != .pterodactylServerID
    }
    
    // /config show [key]
    // /config set <key> <value>
    // /config reset <key>
    var options: [ApplicationCommand.Option]? = [
        .init(
            type: .subCommand,
            name: "show",
            description: "Shows this server's configuration values",
            options: [
                .init(
                    type: .string,
                    name: "key",
                    description: "Guild configuration key",
                    required: false
                )
            ]
        ),
        .init(
            type: .subCommand,
            name: "set",
            description: "Sets a guild configuration value",
            options: [
                .init(
                    type: .string,
                    name: "key",
                    description: "Guild configuration key",
                    required: true
                ),
                .init(
                    type: .string,
                    name: "value",
                    description: "New value; format depends on the selected key",
                    required: true
                )
            ]
        ),
        .init(
            type: .subCommand,
            name: "reset",
            description: "Resets a guild configuration value to its default",
            options: [
                .init(
                    type: .string,
                    name: "key",
                    description: "Guild configuration key",
                    required: true
                )
            ]
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        // We handle "/config show" separately, as it's the only command that does not need a `key` argument
        if
            let showCommand = applicationCommand.option(named: "show"),
            showCommand.option(named: "key")?.value == nil
        {
            try await client.respond(token: interaction.token, payload: createFullConfigPayload(config: context.config))
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
            guard Self.guildConfigKeys.contains(configKey) else {
                throw DiscordCommandError.invalidConfigKey(stringKey)
            }
            return try context.config.value(for: configKey)
        }
        
        if let showCommand = applicationCommand.option(named: "show") {
            if let keyString = showCommand.option(named: "key")?.value?.stringValue {
                try await respond("The value of `\(keyString)` is `\(value(for: keyString))`")
            } else {
                try await respond(createFullConfigPayload(config: context.config))
            }
        } else if let setCommand = applicationCommand.option(named: "set") {
            let keyString = try setCommand.requireOption(named: "key").requireString()
            let valueString = try setCommand.requireOption(named: "value").requireString()
            guard let configKey = ConfigKey(rawValue: keyString) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            guard Self.guildConfigKeys.contains(configKey) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            if configKey == .reminderChannel {
                let channel = try await client.getChannel(id: .init(valueString)).decode()
                guard channel.guild_id == context.guildID else {
                    throw DiscordCommandError.reminderChannelNotInGuild
                }
            }
            try context.config.setValue(valueString, for: configKey)
            if configKey == .foundryFeaturesEnabled, !context.config.foundryFeaturesEnabled {
                await context.bookings.cancelAllBookings()
                let updatedPolls = await context.datePolls.reconcileBookingLinks(bookings: await context.bookings.allBookings)
                await DatePollMessageSynchronizer.synchronize(
                    updatedPolls,
                    datePolls: context.datePolls,
                    foundryFeaturesEnabled: context.config.foundryFeaturesEnabled,
                    client: client
                )
            }
            if configKey == .foundryFeaturesEnabled {
                await refreshDatePollMessages(context: context, client: client)
            }
            try await respond("The value `\(keyString)` was updated to `\(valueString)`.")
        } else if let resetCommand = applicationCommand.option(named: "reset") {
            let keyString = try resetCommand.requireOption(named: "key").requireString()
            guard let configKey = ConfigKey(rawValue: keyString) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            guard Self.guildConfigKeys.contains(configKey) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            let newValue = try context.config.resetValue(for: configKey)
            if configKey == .foundryFeaturesEnabled {
                await refreshDatePollMessages(context: context, client: client)
            }
            try await respond("The value `\(keyString)` was reset to its default value `\(newValue)`.")
        } else {
            throw DiscordCommandError.missingSubcommand
        }
    }
    
    private func createFullConfigPayload(config: GuildConfig) -> Payloads.EditWebhookMessage {
        let embed = Embed(
            title: "Bot Configuration",
            description: "Here are the current configuration values",
            fields: Self.guildConfigKeys.compactMap { key in
                Embed.Field(
                    name: key.rawValue,
                    value: (try? config.value(for: key)) ?? "Unavailable",
                    inline: true
                )
            }
        )
        return .init(embeds: [embed])
    }

    private func refreshDatePollMessages(context: GuildContext, client: any DiscordClient) async {
        let polls = await context.datePolls.publishedPolls()
        for poll in polls {
            guard let messageID = poll.messageID else { continue }
            do {
                try await client.updateMessage(
                    channelId: poll.channelID,
                    messageId: messageID,
                    payload: DatePollRenderer.messagePayload(
                        for: poll,
                        foundryFeaturesEnabled: context.config.foundryFeaturesEnabled
                    )
                ).guardSuccess()
            } catch {
                logger.warning("Failed to refresh date poll after Foundry feature change: \(error)")
            }
        }
    }
    
}
