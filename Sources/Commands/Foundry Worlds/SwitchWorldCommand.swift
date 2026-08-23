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
        .init(
            type: .string,
            name: "world_id",
            description: "The ID of the world to switch to",
            required: true
        ),
        .init(
            type: .boolean,
            name: "force",
            description: "Forces the switch even if world switching is locked",
            required: false
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        guard
            let member = interaction.member,
            let user = member.user
        else {
            throw DiscordCommandError.noUser
        }
        
        let world = try await parseWorld(from: applicationCommand, optionName: "world_id")
        
        // Only the application owner can use `force:true` to switch while locked.
        if WorldLockService.shared.isWorldSwitchingLocked() {
            guard applicationCommand.option(named: "force")?.value?.boolValue == true else {
                throw DiscordCommandError.worldSwitchingIsLocked
            }
            
            // Application ownership is separate from guild-local administrator permission.
            guard context.permissions.isApplicationOwner(user.id) else {
                throw DiscordCommandError.forceSwitchWorldPermissionDenied(required: .admin)
            }
            
            // The application owner may now force the switch.
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
        try await PterodactylAPI.shared.changeWorld(to: world.id, restart: true)
        
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
