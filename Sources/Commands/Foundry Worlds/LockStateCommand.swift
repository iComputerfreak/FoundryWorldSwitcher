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
            message = "World switching is currently **locked**. " +
            "If you believe this is a mistake or need to switch the active world, please contact a server administrator."
        } else {
            message = "World switching is currently **unlocked**."
        }
        
        try await client.respond(
            token: interaction.token,
            message: message
        )
    }
}
