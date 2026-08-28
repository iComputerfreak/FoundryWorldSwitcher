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
    let description = "Shows current or selected Foundry world info; unavailable when Foundry is disabled"
    let permissionsLevel: BotPermissionLevel = .user
    let requiresFoundryFeatures = true
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
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        let localization = context.config.localization
        var world: FoundryWorld?
        var isCurrentWorld: Bool? = nil
        
        // MARK: Get the world
        do {
            world = try await parseOptionalWorld(from: applicationCommand, optionName: "world_id")
        } catch DiscordCommandError.worldDoesNotExist(worldID: let worldID) {
            try await client.respond(
                token: interaction.token,
                message: localization.string("world.info.not_found", table: "Commands", worldID)
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
            description = localization.string("world.info.no_description", table: "Commands")
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
                content: isCurrentWorld == true
                    ? localization.string("world.info.current", table: "Commands")
                    : localization.string("world.info.selected", table: "Commands", world.title),
                embeds: [
                    .init(
                        title: world.title,
                        type: .rich,
                        description: description,
                        color: messageColor,
//                        thumbnail: backgroundURL.map({ .init(url: .exact($0)) }),
                        fields: [
                            .init(name: localization.string("world.info.field.id", table: "Commands"), value: world.id),
                            .init(name: localization.string("world.info.field.core_version", table: "Commands"), value: world.coreVersion),
                            .init(name: localization.string("world.info.field.system", table: "Commands"), value: world.system),
                            .init(name: localization.string("world.info.field.system_version", table: "Commands"), value: world.systemVersion),
                            .init(
                                name: localization.string("world.info.field.last_played", table: "Commands"),
                                value: world.lastPlayed.map(localization.dateTime) ?? localization.string("common.unknown", table: "Commands")
                            ),
                            .init(
                                name: localization.string("world.info.field.note", table: "Commands"),
                                value: localization.string(
                                    lockState ? "world.info.locked" : "world.info.unlocked",
                                    table: "Commands"
                                )
                            ),
                        ]
                    )
                ]
            )
        ).guardSuccess()
    }
}
