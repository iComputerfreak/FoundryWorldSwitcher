//
//  WorldInfoCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation
import Logging
import DiscordBM

struct WorldInfoCommand: DiscordCommand {
    let name = "worldinfo"
    let description = "Displays information about the current world or a given world ID."
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        guard let world = try await PterodactylAPI.shared.currentWorld() else {
            try await client.updateOriginalInteractionResponse(
                token: interaction.token,
                payload: .init(content: "Error loading world information.")
            ).guardSuccess()
            return
        }
        try await client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: .init(
                // TODO: Display "current world" or "world `xyz`")
                content: "Here is some information about the current world.",
                embeds: [
                    .init(
                        title: world.title,
                        type: .rich,
                        description: world.description?.isEmpty == false ? world.description! : "*No Description*",
                        color: nil, // TODO: Current world? => green, else red
                        image: nil, // TODO: Load background image
                        thumbnail: nil,
                        fields: [
                            .init(name: "ID", value: world.id),
                            .init(name: "Core Version", value: world.coreVersion),
                            .init(name: "System", value: world.system),
                            .init(name: "System Version", value: world.systemVersion),
                            .init(
                                name: "Last Played",
                                value: world.lastPlayed.map(Utils.dateFormatter.string(from:)) ?? "Unknown"
                            ),
                        ]
                    )
                ]
            )
        ).guardSuccess()
    }
}
