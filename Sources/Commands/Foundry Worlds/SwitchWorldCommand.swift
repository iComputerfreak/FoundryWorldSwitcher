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
    let description = "Switches the active Foundry world; unavailable when Foundry features are disabled"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    let requiresFoundryFeatures = true
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .string,
            name: "world_id",
            description: "Foundry world ID to activate",
            required: true
        ),
        .init(
            type: .boolean,
            name: "force",
            description: "Overrides the world-switching lock; application owner only",
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
        
        let force = applicationCommand.option(named: "force")?.value?.boolValue == true
        if force {
            // Application ownership is separate from guild-local administrator permission.
            guard context.permissions.isApplicationOwner(user.id) else {
                throw DiscordCommandError.forceSwitchWorldPermissionDenied(required: .admin)
            }
        }

        // The operation slot closes the gap between the lock check and Pterodactyl changes.
        let operationID = try WorldLockService.shared.beginManualWorldSwitching(force: force)
        defer { WorldLockService.shared.endManualWorldSwitching(operationID: operationID) }

        let world = try await parseWorld(from: applicationCommand, optionName: "world_id")
        
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
        await presenceService.refresh(forceWorldRefresh: true)
        
        try await client.respond(
            token: interaction.token,
            message: "Successfully switched the world to `\(world.title)`."
        )
    }
}
