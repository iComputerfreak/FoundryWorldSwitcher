// Copyright © 2024 Jonas Frey. All rights reserved.

import Foundation
import DiscordBM
import Logging

struct UpdateCacheCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "updatecache"
    let description = "Refreshes cached Foundry world metadata from Pterodactyl"
    let permissionsLevel: BotPermissionLevel = .admin
    let requiresFoundryFeatures = true
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        let localization = context.config.localization
        try await client.respond(
            token: interaction.token,
            message: localization.string("cache.updating", table: "Commands")
        )
        
        try await PterodactylAPI.shared.updateCache()
        
        try await client.respond(
            token: interaction.token,
            message: localization.string("cache.updated", table: "Commands")
        )
    }
    
}
