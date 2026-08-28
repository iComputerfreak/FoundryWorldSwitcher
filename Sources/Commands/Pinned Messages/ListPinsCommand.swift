// Copyright © 2024 Jonas Frey. All rights reserved.

import Foundation
import DiscordBM
import Logging

struct ListPinsCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "listpins"
    let description = "Lists saved booking-schedule messages available in this server"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        guard let guild = interaction.guild_id else { throw DiscordCommandError.noGuild }
        let pinnedMessages = context.config.pinnedBookingMessages.filter {
            context.config.foundryFeaturesEnabled || $0.worldID == nil
        }
        let localization = context.config.localization
        
        func formattedMessages() -> String {
            if pinnedMessages.isEmpty {
                return localization.string("pins.empty", table: "Commands")
            }
            return pinnedMessages.map { message in
                "* \(formatMessage(message, in: guild, localization: localization))"
            }
            .joined(separator: "\n")
        }
        
        try await client.respond(
            token: interaction.token,
            message: localization.string("pins.list", table: "Commands", formattedMessages())
        )
    }
    
    private func formatMessage(
        _ pinnedMessage: PinnedBookingMessage,
        in guild: GuildSnowflake,
        localization: LocalizationContext
    ) -> String {
        let guildID = guild.rawValue
        let channelID = pinnedMessage.channelID.rawValue
        let messageID = pinnedMessage.messageID.rawValue
        let messageLink = "https://discord.com/channels/\(guildID)/\(channelID)/\(messageID)"
        var messageString = "\(messageLink)"
        if
            let role = pinnedMessage.role,
            let world = pinnedMessage.worldID
        {
            messageString += localization.string("pins.filters.role_world", table: "Commands", role.rawValue, world)
        } else if let role = pinnedMessage.role {
            messageString += localization.string("pins.filters.role", table: "Commands", role.rawValue)
        } else if let world = pinnedMessage.worldID {
            messageString += localization.string("pins.filters.world", table: "Commands", world)
        }
        return messageString
    }
}
