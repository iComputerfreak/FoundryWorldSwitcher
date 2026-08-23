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
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        let role = applicationCommand.option(named: "role")?.value?.stringValue.flatMap(RoleSnowflake.init)
        
        let pastEvents = await context.bookings.completedBookings
            .compactMap { $0 as? EventBooking }
            .filter { booking in
                guard let role else { return true }
                return booking.campaignRoleSnowflake == role
            }

        let bookingMessages = try await Utils.createBookingMessages(for: pastEvents)

        let payload: Payloads.EditWebhookMessage
        if bookingMessages.isEmpty {
            payload = .init(content: "There are no past event bookings.")
        } else {
            payload = .init(
                content: "## Past Sessions (latest 10 sessions)\n" + bookingMessages.joined(separator: "\n\n"),
                allowed_mentions: .init()
            )
        }
        
        try await client.respond(token: interaction.token, payload: payload)
    }
}
