//
//  RestartWorldCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation
import DiscordBM
import Logging

struct RestartWorldCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "restartworld"
    let description = "Restarts the Foundry VTT Server"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        // Send the restart command
        try await PterodactylAPI.shared.restartServer()
        try await client.respond(
            token: interaction.token,
            message: "Restaring the Foundry VTT server. This should just take a second."
        )
    }
}
