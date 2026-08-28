//
//  UpdatePinsCommand.swift
//
//
//  Created by Jonas Frey on 15.04.24.
//

import DiscordBM
import Foundation
import Logging

class UpdatePinsCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: UpdatePinsCommand.self))
    let name = "updatepins"
    let description = "Refreshes all saved booking-schedule messages in this server"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        try await context.bookings.updatePinnedBookings()
        try await client.respond(
            token: interaction.token,
            message: context.config.localization.string("pins.updated", table: "Commands")
        )
    }
}
