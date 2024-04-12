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
        let bookings = await bookingsService.bookings
        try await client.respond(
            token: interaction.token,
            payload: .init(
                content: formatBookings(bookings),
                allowed_mentions: .init() // Don't allow mentions on this message
            )
        )
    }
    
    private func formatBookings(_ bookings: [Booking]) -> String {
        bookings
            .sorted { $0.date < $1.date }
            .map { booking in
                let date = booking.date
                let author = booking.author
                let world = booking.worldID
                let role = booking.roleSnowflake.map { $0.description } ?? "None"
                // Sunday, 01.01.2024 at 18:00
                // @Role plays on world TWBTW
                return "\(date) - \(author) - \(world) - \(role)\n" +
                "\(Utils.mention(of: role))"
            }
            .joined(separator: "\n\n")
    }
}
