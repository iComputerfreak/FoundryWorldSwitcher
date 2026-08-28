//
//  BookingsCommand.swift
//  
//
//  Created by Jonas Frey on 11.04.24.
//

import DiscordBM
import Foundation
import Logging

struct BookingsCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "bookings"
    let description = "Shows booking records; only external bookings appear when Foundry is disabled"
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        let bookings = await context.bookings.allBookings.filter {
            context.config.foundryFeaturesEnabled || $0.worldID == nil
        }
        let bookingEmbeds = try await Utils.createBookingEmbeds(for: bookings, localization: context.config.localization)
        
        let payload: Payloads.EditWebhookMessage
        if bookingEmbeds.isEmpty {
            payload = .init(content: context.config.localization.string("booking.empty", table: "Commands"))
        } else {
            payload = .init(embeds: bookingEmbeds, allowed_mentions: .init())
        }
        
        try await client.respond(token: interaction.token, payload: payload)
    }
}
