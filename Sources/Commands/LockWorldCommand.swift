//
//  LockWorldCommand.swift
//
//
//  Created by Jonas Frey on 13.04.24.
//

import DiscordBM
import Foundation
import Logging

struct LockWorldCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: LockWorldCommand.self))
    let name = "lockworld"
    let description = "Locks a world, preventing others from switching to another world."
    let permissionsLevel: BotPermissionLevel = .admin
    
    // TODO: Add option to specify the duration as "7h" or "3d" or no value for "forever"
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        
    }
}

