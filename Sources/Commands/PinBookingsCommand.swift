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
        
        // Save the token for updating later
        BotConfig.shared.pinnedBookingMessages.append(.init(token: interaction.token, worldID: world?.id, role: role))
        
        let embeds = try await Utils.createBookingEmbeds(for: bookingsService.bookings)
        
        let info = "# Upcoming Bookings"
        let payload: Payloads.EditWebhookMessage
        if embeds.isEmpty {
            payload = .init(content: "\(info)\nThere are no bookings scheduled right now.")
        } else {
            payload = .init(content: "\(info)", embeds: embeds, allowed_mentions: .init())
        }
        
        try await client.respond(token: interaction.token, payload: payload)
    }
}
