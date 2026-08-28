//
//  PinBookingsCommand.swift
//
//
//  Created by Jonas Frey on 14.04.24.
//

import DiscordBM
import Foundation
import Logging

struct PinBookingsCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: PinBookingsCommand.self))
    let name = "pinbookings"
    let description = "Posts an auto-updating schedule of active bookings"
    let permissionsLevel: BotPermissionLevel = .admin
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .role,
            name: "role",
            description: "Filter event bookings by campaign role; excludes reservations",
            required: false
        ),
        .init(
            type: .string,
            name: "world_id",
            description: "Filter by Foundry world ID; unavailable when Foundry is disabled",
            required: false
        ),
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        guard context.config.foundryFeaturesEnabled || applicationCommand.option(named: "world_id") == nil else {
            throw DiscordCommandError.foundryFeaturesDisabled
        }
        let world = context.config.foundryFeaturesEnabled
            ? try await parseOptionalWorld(from: applicationCommand, optionName: "world_id")
            : nil
        let role = applicationCommand.option(named: "role")?.value?.stringValue.flatMap(RoleSnowflake.init)
        
        // We cannot use the normal respond mechanic, as this will give us a temporary interaction token
        // that will be invalidated later
        guard let channelID = interaction.channel?.id else {
            throw DiscordCommandError.noChannel
        }
        
        // Create an empty message and save its ID
        let pinnedMessage = try await client.createMessage(
            channelId: channelID,
            payload: .init(content: context.config.localization.string("pins.loading", table: "Commands"))
        ).decode()
        logger.info("Pinning message \(pinnedMessage.id.rawValue) in channel \(pinnedMessage.channel_id.rawValue).")
        context.config.pinnedBookingMessages.append(
            .init(
                channelID: pinnedMessage.channel_id,
                messageID: pinnedMessage.id,
                worldID: world?.id,
                role: role
            )
        )
        
        // Delete the interaction response, so only the newly created message remains
        try await client.deleteOriginalInteractionResponse(token: interaction.token).guardSuccess()
        
        // Immediately update/create the message
        try await context.bookings.updatePinnedBookings()
    }
}
