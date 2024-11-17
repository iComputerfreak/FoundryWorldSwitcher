// Copyright © 2024 Jonas Frey. All rights reserved.

import DiscordBM
import Foundation
import Logging

struct SessionLogCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "sessionlog"
    let description = "Shows a list of all past events"
    let permissionsLevel: BotPermissionLevel = .user
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .role,
            name: "role",
            description: "The role by which to filter the bookings",
            required: false
        ),
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        let role = applicationCommand.option(named: "role")?.value?.stringValue.flatMap(RoleSnowflake.init)
        
        let pastEvents = await bookingsService.completedBookings.filter { $0 is EventBooking }
        let bookingEmbed = try await Utils.createBookingEmbeds(for: pastEvents)
        
        let payload: Payloads.EditWebhookMessage
        if bookingEmbed.isEmpty {
            payload = .init(content: "There are no past event bookings.")
        } else {
            payload = .init(embeds: bookingEmbed, allowed_mentions: .init())
        }
        
        try await client.respond(token: interaction.token, payload: payload)
    }
}
