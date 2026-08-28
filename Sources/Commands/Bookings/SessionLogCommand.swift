// Copyright © 2024 Jonas Frey. All rights reserved.

import DiscordBM
import Foundation
import Logging

struct SessionLogCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "sessionlog"
    let description = "Shows up to 10 completed, non-cancelled event sessions"
    let permissionsLevel: BotPermissionLevel = .user
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .role,
            name: "role",
            description: "Campaign role used to filter listed event sessions",
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
            .filter { context.config.foundryFeaturesEnabled || $0.worldID == nil }
            .filter { booking in
                guard let role else { return true }
                return booking.campaignRoleSnowflake == role
            }

        let bookingMessages = try await Utils.createBookingMessages(for: pastEvents, localization: context.config.localization)
        let localization = context.config.localization

        let payload: Payloads.EditWebhookMessage
        if bookingMessages.isEmpty {
            payload = .init(content: localization.string("session_log.empty", table: "Commands"))
        } else {
            payload = .init(
                content: localization.string("session_log.list", table: "Commands", bookingMessages.joined(separator: "\n\n")),
                allowed_mentions: .init()
            )
        }
        
        try await client.respond(token: interaction.token, payload: payload)
    }
}
