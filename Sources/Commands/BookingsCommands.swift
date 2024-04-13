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
    
    private func formatBookings(_ bookings: [any Booking]) -> String {
        guard !bookings.isEmpty else {
            return "There are no bookings scheduled right now."
        }
        
        return bookings
            .sorted { $0.date < $1.date }
            .map { booking in
                let date = booking.date
                let author = booking.author
                let world = booking.worldID
                
                let activityString: String
                if let eventBooking = booking as? EventBooking {
                    let group = eventBooking.campaignRoleSnowflake
                    let topic = eventBooking.topic
                    activityString = "\(DiscordUtils.mention(id: group)) is playing on the world \(world)\n> \(topic)"
                } else {
                    activityString = "\(DiscordUtils.mention(id: author)) is preparing the world \(world)"
                }
                
                // Sunday, 01.01.2024 at 18:00
                // @Role is playing on the world TWBTW
                // *Session 13*
                return """
                **\(date.formatted(date: .complete, time: booking is EventBooking ? .shortened : .omitted))**
                \(activityString)
                """
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .joined(separator: "\n\n")
    }
}
