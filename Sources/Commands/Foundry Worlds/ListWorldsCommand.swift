//
//  ListWorldsCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM
import Logging

struct ListWorldsCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "listworlds"
    let description = "Lists Foundry worlds; unavailable when Foundry features are disabled"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    let requiresFoundryFeatures = true
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        let worlds: [FoundryWorld] = try await PterodactylAPI.shared.worlds()
        let localization = context.config.localization
        func formattedWorlds() -> String {
            if worlds.isEmpty {
                return localization.string("common.none", table: "Commands")
            }
            return worlds.map { world in
                "* \(world.title) (`\(world.id)`)"
            }
            .joined(separator: "\n")
        }
        
        try await client.respond(
            token: interaction.token,
            message: localization.string("world.list", table: "Commands", formattedWorlds())
        )
    }
}
