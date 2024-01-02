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
    let description = "Lists all available worlds in Foundry VTT."
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        let worlds: [FoundryWorld] = try await PterodactylAPI.shared.worlds()
        func formattedWorlds() -> String {
            if worlds.isEmpty {
                return "*None*"
            }
            return worlds.map { world in
                "* \(world.title) (`\(world.id)`)"
            }
            .joined(separator: "\n")
        }
        
        try await client.respond(
            token: interaction.token,
            message: """
            ## Worlds
            \(formattedWorlds())
            """
        )
    }
}
