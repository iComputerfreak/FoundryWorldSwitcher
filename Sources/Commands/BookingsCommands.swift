//
//  BookingsCommand.swift
//  
//
//  Created by Jonas Frey on 11.04.24.
//

import DiscordBM
import Foundation
import Logging

struct BookingsCommands: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "bookings"
    let description = "Shows a list of all future reservations"
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        let bookingEmbeds = try await Utils.createBookingEmbeds(for: bookingsService.bookings)
        
        let payload: Payloads.EditWebhookMessage
        if bookingEmbeds.isEmpty {
            payload = .init(content: "There are no bookings scheduled right now.")
        } else {
            payload = .init(embeds: bookingEmbeds, allowed_mentions: .init())
        }
        
        try await client.respond(token: interaction.token, payload: payload)
    }
}
