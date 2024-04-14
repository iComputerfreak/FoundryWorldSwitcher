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
    let description = "Unlocks world switching, allowing others to switch worlds again"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        try WorldLockService.shared.unlockWorldSwitching()
        
        try await client.respond(
            token: interaction.token,
            message: "World switching has been unlocked."
        )
    }
}
