//
//  UnlockWorldCommand.swift
//
//
//  Created by Jonas Frey on 13.04.24.
//

import DiscordBM
import Foundation
import Logging

struct UnlockWorldCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: UnlockWorldCommand.self))
    let name = "unlockworld"
    let description = "Application owner only: removes the global world-switching lock"
    let permissionsLevel: BotPermissionLevel = .admin
    let requiresFoundryFeatures = true
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        guard let user = interaction.member?.user else {
            throw DiscordCommandError.noUser
        }
        guard context.permissions.isApplicationOwner(user.id) else {
            throw DiscordCommandError.globalWorldUnlockPermissionDenied
        }

        try WorldLockService.shared.unlockWorldSwitching()
        await presenceService.refresh()
        
        try await client.respond(
            token: interaction.token,
            message: context.config.localization.string("world.unlocked", table: "Commands")
        )
    }
}
