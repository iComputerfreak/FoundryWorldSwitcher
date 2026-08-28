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
        let localization = context.config.localization
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
                try await respond(localization.string("config.value", table: "Commands", keyString, try value(for: keyString)))
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
            if configKey == .language {
                let message = try await context.configUpdates.perform {
                    try await setLanguage(
                        valueString,
                        keyString: keyString,
                        context: context,
                        client: client
                    )
                }
                try await respond(message)
                return
            }
            let message = try await context.configUpdates.perform {
                try context.config.setValue(valueString, for: configKey)
                if configKey == .foundryFeaturesEnabled, !context.config.foundryFeaturesEnabled {
                    await context.bookings.cancelAllBookings()
                    let updatedPolls = await context.datePolls.reconcileBookingLinks(bookings: await context.bookings.allBookings)
                    await DatePollMessageSynchronizer.synchronize(
                        updatedPolls,
                        datePolls: context.datePolls,
                        client: client
                    )
                }
                if configKey == .foundryFeaturesEnabled {
                    try await refreshDatePollMessages(context: context, client: client)
                    await presenceService.refresh(forceWorldRefresh: context.config.foundryFeaturesEnabled)
                }
                let updatedLocalization = context.config.localization
                return updatedLocalization.string("config.updated", table: "Commands", keyString, try context.config.value(for: configKey))
            }
            try await respond(message)
        } else if let resetCommand = applicationCommand.option(named: "reset") {
            let keyString = try resetCommand.requireOption(named: "key").requireString()
            guard let configKey = ConfigKey(rawValue: keyString) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            guard Self.guildConfigKeys.contains(configKey) else {
                throw DiscordCommandError.invalidConfigKey(keyString)
            }
            if configKey == .language {
                let message = try await context.configUpdates.perform {
                    try await resetLanguage(keyString: keyString, context: context, client: client)
                }
                try await respond(message)
                return
            }
            let message = try await context.configUpdates.perform {
                let newValue = try context.config.resetValue(for: configKey)
                if configKey == .foundryFeaturesEnabled {
                    try await refreshDatePollMessages(context: context, client: client)
                    await presenceService.refresh(forceWorldRefresh: context.config.foundryFeaturesEnabled)
                }
                let updatedLocalization = context.config.localization
                return updatedLocalization.string("config.reset", table: "Commands", keyString, newValue)
            }
            try await respond(message)
        } else {
            throw DiscordCommandError.missingSubcommand
        }
    }
    
    private func createFullConfigPayload(config: GuildConfig) -> Payloads.EditWebhookMessage {
        let localization = config.localization
        let embed = Embed(
            title: localization.string("config.title", table: "Commands"),
            description: localization.string("config.description", table: "Commands"),
            fields: Self.guildConfigKeys.compactMap { key in
                Embed.Field(
                    name: key.rawValue,
                    value: (try? config.value(for: key)) ?? localization.string("config.value_unavailable"),
                    inline: true
                )
            }
        )
        return .init(embeds: [embed])
    }

    private func refreshDatePollMessages(context: GuildContext, client: any DiscordClient) async throws {
        let polls = try await context.datePolls.markPublishedMessagesForSync()
        await DatePollMessageSynchronizer.synchronize(
            polls,
            datePolls: context.datePolls,
            client: client
        )
    }

    private func refreshLocalizedMessages(
        context: GuildContext,
        preparedPolls: [DatePoll],
        events: [SchedulerEvent],
        client: any DiscordClient
    ) async -> String? {
        await context.scheduler.schedule(events)
        await DatePollMessageSynchronizer.synchronize(
            preparedPolls,
            datePolls: context.datePolls,
            client: client
        )
        do {
            try await context.bookings.updatePinnedBookings()
            return nil
        } catch {
            logger.warning("Failed to refresh pinned bookings after language change: \(error)")
            return context.config.localization.string("config.language.pin_refresh_failed", table: "Commands")
        }
    }

    private func setLanguage(
        _ value: String,
        keyString: String,
        context: GuildContext,
        client: any DiscordClient
    ) async throws -> String {
        let prepared = try await context.datePolls.preparePublishedMessagesForSync()
        do {
            try context.config.setValue(value, for: .language)
        } catch {
            await context.scheduler.schedule(prepared.events)
            throw error
        }
        let warning = await refreshLocalizedMessages(
            context: context,
            preparedPolls: prepared.polls,
            events: prepared.events,
            client: client
        )
        let localization = context.config.localization
        return localization.string("config.updated", table: "Commands", keyString, context.config.language.rawValue)
            + (warning.map { "\n\($0)" } ?? "")
    }

    private func resetLanguage(
        keyString: String,
        context: GuildContext,
        client: any DiscordClient
    ) async throws -> String {
        let prepared = try await context.datePolls.preparePublishedMessagesForSync()
        let value: String
        do {
            value = try context.config.resetValue(for: .language)
        } catch {
            await context.scheduler.schedule(prepared.events)
            throw error
        }
        let warning = await refreshLocalizedMessages(
            context: context,
            preparedPolls: prepared.polls,
            events: prepared.events,
            client: client
        )
        let localization = context.config.localization
        return localization.string("config.reset", table: "Commands", keyString, value)
            + (warning.map { "\n\($0)" } ?? "")
    }

}
