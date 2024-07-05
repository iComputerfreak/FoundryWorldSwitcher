// Copyright © 2024 Jonas Frey. All rights reserved.

import Foundation
import DiscordBM
import Logging

struct UpdateCacheCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "updatecache"
    let description = "Invalidates and re-fetches the cache"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        try await client.respond(token: interaction.token, message: "Updating cache...")
        
        try await PterodactylAPI.shared.updateCache()
        
        try await client.respond(token: interaction.token, message: "Cache successfully updated.")
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
