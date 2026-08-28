//
//  LockStateCommand.swift
//
//
//  Created by Jonas Frey on 14.04.24.
//

import DiscordBM
import Foundation
import Logging

struct LockStateCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: LockStateCommand.self))
    let name = "lockstate"
    let description = "Shows global world-switching lock state; unavailable when Foundry is disabled"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    let requiresFoundryFeatures = true
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        let message: String
        if WorldLockService.shared.isWorldSwitchingLocked() {
            message = context.config.localization.string("world.lock_state.locked", table: "Commands")
        } else {
            message = context.config.localization.string("world.lock_state.unlocked", table: "Commands")
        }
        
        try await client.respond(
            token: interaction.token,
            message: message
        )
    }
}
