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
    let description = "Sends the current booking schedule in the channel and updates it when further changes are made"
    let permissionsLevel: BotPermissionLevel = .admin
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .role,
            name: "role",
            description: "The role by which to filter the bookings",
            required: false
        ),
        .init(
            type: .string,
            name: "world_id",
            description: "The world by which to filter the bookings",
            required: false
        ),
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        let world = try await parseOptionalWorld(from: applicationCommand, optionName: "world_id")
        let role = applicationCommand.option(named: "role")?.value?.stringValue.flatMap(RoleSnowflake.init)
        
        // We cannot use the normal respond mechanic, as this will give us a temporary interaction token
        // that will be invalidated later
        guard let channelID = interaction.channel?.id else {
            throw DiscordCommandError.noChannel
        }
        
        // Create an empty message and save its ID
        let pinnedMessage = try await bot.client.createMessage(channelId: channelID, payload: .init()).decode()
        BotConfig.shared.pinnedBookingMessages.append(
            .init(
                channelID: pinnedMessage.channel_id,
                messageID: pinnedMessage.id,
                worldID: world?.id,
                role: role
            )
        )
        
        // Delete the interaction response, so only the newly created message remains
        try await bot.client.deleteOriginalInteractionResponse(token: interaction.token).guardSuccess()
        
        // Immediately update/create the message
        try await bookingsService.updatePinnedBookings()
    }
}
