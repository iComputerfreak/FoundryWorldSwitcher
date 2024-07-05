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
    let description = "Updates all pinned booking messages"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        try await bookingsService.updatePinnedBookings()
        try await client.respond(
            token: interaction.token,
            message: "Updated all pinned booking messages."
        )
    }
}
