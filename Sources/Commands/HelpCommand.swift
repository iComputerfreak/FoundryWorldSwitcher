//
//  HelpCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation
import DiscordBM
import Logging

struct HelpCommand: DiscordCommand {
    var logger: Logger = .init(label: String(describing: Self.self))
    let name = "help"
    let description = "Displays information about the use of this bot."
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        try await client.respond(
            token: interaction.token,
            // TODO: Update
            message: """
            You can use this bot to view information about the FoundryVTT server and manage the currently running world.
            You can use `/worldinfo` to show the currently running world and use `/switchworld <world_id>` to change the active world. To get the world ID, use `/listworlds`.
            """
        )
    }
}
