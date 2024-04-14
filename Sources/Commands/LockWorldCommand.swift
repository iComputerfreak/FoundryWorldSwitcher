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
    let description = "Locks a world, preventing others from switching to another world"
    let permissionsLevel: BotPermissionLevel = .admin
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .string,
            name: "worldID",
            description: "The ID of the world to switch to before locking",
            required: false
        ),
        .init(
            type: .string,
            name: "duration",
            description: "The duration for which the world should be locked",
            required: false
        )
    ]
    
    // TODO: Add option to specify the duration as "7h" or "3d" or no value for "forever"
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        let worldID = try applicationCommand.option(named: "worldID")?.requireString()
        let durationString = try applicationCommand.option(named: "duration")?.requireString()
        
        if worldID != nil {
            try await PterodactylAPI.shared.changeWorld(to: worldID!)
        }
        
        try WorldLockService.shared.lockWorldSwitching()
        
        if durationString != nil {
            let duration = try DurationParser.duration(from: durationString!)
            let unlockTime = Date.now.addingTimeInterval(duration)
            await Scheduler.shared.schedule(.init(dueDate: unlockTime, eventType: .unlockWorldSwitching))
        }
        
        try await client.respond(
            token: interaction.token,
            // TODO: Use world name instead of ID
            message: "The world has been \(worldID == nil ? "" : "switched to \(worldID!) and ")locked."
        )
    }
}
