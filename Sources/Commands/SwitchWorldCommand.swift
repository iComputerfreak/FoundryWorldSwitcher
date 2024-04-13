//
//  SwitchWorldCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation
import DiscordBM
import Logging

struct SwitchWorldCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "switchworld"
    let description = "Switches the currently active Foundry VTT world"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    let options: [ApplicationCommand.Option]? = [
        .init(type: .string, name: "world_id", description: "The ID of the world to switch to", required: nil)
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        guard let world = try await Utils.parseWorld(from: applicationCommand) else {
            throw DiscordCommandError.missingArgument(argumentName: "world_id")
        }
        
        try await client.respond(
            token: interaction.token,
            message: "Stopping the server..."
        )
        try await PterodactylAPI.shared.stopServer()
        
        // Update the startup variable
        try await client.respond(
            token: interaction.token,
            message: "Switching to the world `\(world.title)`..."
        )
        try await PterodactylAPI.shared.changeWorld(to: world.id)
        
        try await client.respond(
            token: interaction.token,
            message: "Starting the server..."
        )
        try await PterodactylAPI.shared.startServer()
        
        try await client.respond(
            token: interaction.token,
            message: "Successfully switched the world to `\(world.title)`."
        )
    }
}
