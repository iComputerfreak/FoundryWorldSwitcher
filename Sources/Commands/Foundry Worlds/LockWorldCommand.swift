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
    let description = "Locks global world switching; unavailable when Foundry features are disabled"
    let permissionsLevel: BotPermissionLevel = .admin
    let requiresFoundryFeatures = true
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .string,
            name: "world_id",
            description: "Foundry world ID to activate before locking switching",
            required: false
        ),
        .init(
            type: .string,
            name: "duration",
            description: "Lock duration, for example 1h 30m; omit for an indefinite lock",
            required: false
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        let world = try await parseOptionalWorld(from: applicationCommand, optionName: "world_id")
        let duration = try applicationCommand
            .option(named: "duration")?
            .value?
            .stringValue
            .map(DurationParser.duration(from:))
        
        let lock = try WorldLockService.shared.lockWorldSwitching()
        if let worldID = world?.id {
            do {
                try await PterodactylAPI.shared.changeWorld(to: worldID, restart: true)
            } catch {
                _ = try? WorldLockService.shared.unlockManualWorldSwitching(acquiredAt: lock.acquiredAt)
                throw error
            }
        }
        
        if let duration {
            let unlockTime = Date.now.addingTimeInterval(duration)
            await context.scheduler.schedule(
                .init(dueDate: unlockTime, eventType: .unlockManualWorldSwitching(acquiredAt: lock.acquiredAt))
            )
        }
        await presenceService.refresh(forceWorldRefresh: world != nil)
        
        let localization = context.config.localization
        let durationString = duration.map {
            Utils.durationString(for: $0, unitStyle: .long, localization: localization)
        }
        let message: String
        switch (world, durationString) {
        case (.some(let world), .some(let durationString)):
            message = localization.string("world.locked.switched_timed", table: "Commands", world.title, durationString)
        case (.some(let world), .none):
            message = localization.string("world.locked.switched", table: "Commands", world.title)
        case (.none, .some(let durationString)):
            message = localization.string("world.locked.timed", table: "Commands", durationString)
        case (.none, .none):
            message = localization.string("world.locked", table: "Commands")
        }
        
        try await client.respond(
            token: interaction.token,
            message: message
        )
    }
}
