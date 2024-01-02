//
//  WorldInfoCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation
import Logging
import DiscordBM
import HTML2Markdown

struct WorldInfoCommand: DiscordCommand {
    let name = "worldinfo"
    let description = "Displays information about the current world or a given world ID."
    let permissionsLevel: BotPermissionLevel = .user
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .string,
            name: "world_id",
            description: "The ID of the world to show information about.",
            required: false
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        let world: FoundryWorld
        let isCurrentWorld: Bool?
        
        // MARK: Get the world
        if let worldArg = try applicationCommand.option(named: options!.first!.name)?.value?.requireString() {
            do {
                world = try await PterodactylAPI.shared.world(for: worldArg)
            } catch PterodactylAPIError.invalidResponseCode(let code) {
                // If we get a 500 error, maybe the world ID does not exist.
                guard code == 500 else {
                    throw PterodactylAPIError.invalidResponseCode(code)
                }
                try await client.updateOriginalInteractionResponse(
                    token: interaction.token,
                    payload: .init(content: "There was an error trying to get information about the world. Are you sure a world with the ID `\(worldArg)` exists?")
                ).guardSuccess()
                logger.error("Error getting world information for world '\(worldArg)'. HTTP Request returned code \(code)")
                return
            }
            // We try getting the current world, but if we fail, it is okay
            do {
                let currentWorldID = try await PterodactylAPI.shared.currentWorld().id
                isCurrentWorld = currentWorldID == world.id
            } catch {
                // Error getting the current world. We just set isCurrentWorld to nil for 'unknown' and continue
                isCurrentWorld = nil
            }
        } else {
            // Use the current world
            world = try await PterodactylAPI.shared.currentWorld()
            isCurrentWorld = true
        }
        
        // MARK: Determine the message color
        let messageColor: DiscordColor?
        if let isCurrentWorld {
            messageColor = isCurrentWorld ? .green : .red
        } else {
            messageColor = nil
        }
        
        // MARK: Parse the description and convert it to Markdown
        let description: String
        if let descriptionHTML = world.description {
            do {
                description = try HTMLParser().parse(html: descriptionHTML).toMarkdown()
            } catch {
                logger.warning("Error parsing HTML description of world '\(world.id)'. Using raw HTML.")
                // As a fallback, use the raw HTML
                description = descriptionHTML
            }
        } else {
            description = "*No Description*"
        }
        
        // MARK: Get a download link for the background image
        // FIXME: Does not work, because the link initiates a download instead of showing the image
//        let backgroundURL: String?
//        if let backgroundPath = world.backgroundPath {
//            let fullPath = "/data/Data/\(backgroundPath)"
//            backgroundURL = try await PterodactylAPI.shared.downloadLink(for: fullPath)
//        } else {
//            backgroundURL = nil
//        }
        
        try await client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: .init(
                content: "Here is some information about the \(isCurrentWorld == true ? "current world" : "world `\(world.title)`").",
                embeds: [
                    .init(
                        title: world.title,
                        type: .rich,
                        description: description,
                        color: messageColor,
//                        thumbnail: backgroundURL.map({ .init(url: .exact($0)) }),
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
