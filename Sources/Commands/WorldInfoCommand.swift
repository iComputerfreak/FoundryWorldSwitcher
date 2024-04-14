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
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "worldinfo"
    let description = "Displays information about the current world or a given world ID"
    let permissionsLevel: BotPermissionLevel = .user
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .string,
            name: "world_id",
            description: "The ID of the world to show information about",
            required: false
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        var world: FoundryWorld?
        var isCurrentWorld: Bool? = nil
        
        // MARK: Get the world
        do {
            world = try await parseWorld(from: applicationCommand, optionName: "world_id")
        } catch DiscordCommandError.worldDoesNotExist(worldID: let worldID) {
            try await client.respond(
                token: interaction.token,
                message: "There was an error trying to get information about the world. Are you sure a world with the ID `\(worldID)` exists?"
            )
            return
        }
        do {
            let currentWorld = try await PterodactylAPI.shared.currentWorld()
            if world == nil {
                // If we did not get a world as an argument, we use the current one
                world = currentWorld
            }
            isCurrentWorld = world?.id == currentWorld.id
        } catch {
            // If we already have a valid world, we don't care about this error, otherwise, we throw the error
            if world == nil {
                throw error
            }
        }
        
        guard let world else {
            // We really should not be here. The do-statement above either assigns a valid world or throws an error.
            fatalError("Error getting a valid world.")
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
                logger.warning("Error parsing HTML description of world `\(world.id)`. Using raw HTML.")
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
        
        let lockState = WorldLockService.shared.isWorldSwitchingLocked()
        
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
                            .init(name: "Note", value: "World switching is currently \(lockState ? "**locked**" : "unlocked")."),
                        ]
                    )
                ]
            )
        ).guardSuccess()
    }
}
