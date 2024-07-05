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
            name: "world_id",
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
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        let world = try await parseOptionalWorld(from: applicationCommand, optionName: "world_id")
        let duration = try applicationCommand
            .option(named: "duration")?
            .value?
            .stringValue
            .map(DurationParser.duration(from:))
        
        if let worldID = world?.id {
            try await PterodactylAPI.shared.changeWorld(to: worldID, restart: true)
        }
        
        try WorldLockService.shared.lockWorldSwitching()
        
        if let duration {
            let unlockTime = Date.now.addingTimeInterval(duration)
            await Scheduler.shared.schedule(.init(dueDate: unlockTime, eventType: .unlockWorldSwitching))
        }
        
        var message = "The world has been "
        if let world {
            message += "switched to \(world.title) and "
        }
        message += "locked"
        if let duration {
            message += " for \(Utils.durationString(for: duration))"
        }
        message += "."
        
        try await client.respond(
            token: interaction.token,
            message: message
        )
    }
}
