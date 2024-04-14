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
    
    // TODO: Add options for pinning only filtered bookings (into the campaign channels)
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        // Save the token for updating later
        BotConfig.shared.pinnedContinuationTokens.append(interaction.token)
        
        let embeds = try await Utils.createBookingEmbeds(for: bookingsService.bookings)
        
        let info = "# Upcoming Bookings\n*This message will be updated whenever a booking is added or removed. To stop updates, simply delete this message.*"
        let payload: Payloads.EditWebhookMessage
        if embeds.isEmpty {
            payload = .init(content: "\(info)\nThere are no bookings scheduled right now.")
        } else {
            payload = .init(content: "\(info)", embeds: embeds, allowed_mentions: .init())
        }
        
        try await client.respond(token: interaction.token, payload: payload)
    }
}
