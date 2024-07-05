// Copyright © 2024 Jonas Frey. All rights reserved.

import Foundation
import DiscordBM
import Logging

struct ListPinsCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "listpins"
    let description = "Lists all pinned schedule messages"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        guard let guild = interaction.guild_id else { throw DiscordCommandError.noGuild }
        let pinnedMessages = BotConfig.shared.pinnedBookingMessages
        
        func formattedMessages() -> String {
            if pinnedMessages.isEmpty {
                return "*There are no pinned messages.*"
            }
            return pinnedMessages.map { message in
                "* \(formatMessage(message, in: guild))"
            }
            .joined(separator: "\n")
        }
        
        try await client.respond(
            token: interaction.token,
            message: """
            ## Pinned Booking Messages
            \(formattedMessages())
            """
        )
    }
    
    private func formatMessage(_ pinnedMessage: PinnedBookingMessage, in guild: GuildSnowflake) -> String {
        let guildID = guild.rawValue
        let channelID = pinnedMessage.channelID.rawValue
        let messageID = pinnedMessage.messageID.rawValue
        let messageLink = "https://discord.com/channels/\(guildID)/\(channelID)/\(messageID)"
        var messageString = "\(messageLink)"
        if
            let role = pinnedMessage.role,
            let world = pinnedMessage.worldID
        {
            messageString += " (Role: \(role.rawValue), World: \(world))"
        } else if let role = pinnedMessage.role {
            messageString += " (Role: \(role.rawValue))"
        } else if let world = pinnedMessage.worldID {
            messageString += " (World: \(world))"
        }
        return messageString
    }
}
