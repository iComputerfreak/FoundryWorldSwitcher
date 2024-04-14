//
//  CancelBookingCommand.swift
//
//
//  Created by Jonas Frey on 14.04.24.
//

import DiscordBM
import Foundation
import Logging

class CancelBookingCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: CancelBookingCommand.self))
    let name = "cancelbooking"
    let description = "Cancels a booking for a specific date"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    
    let options: [ApplicationCommand.Option]? = [
        ApplicationCommand.Option(
            type: .string,
            name: "date",
            description: "The date of the booking to cancel",
            required: true
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        guard 
            let member = interaction.member,
            let user = member.user
        else {
            throw DiscordCommandError.noUser
        }
        
        guard let dateString = try applicationCommand.option(named: "date")?.requireString() else {
            throw DiscordCommandError.missingArgument(argumentName: "date")
        }
        guard let date = Utils.dateFormatter.date(from: dateString) else {
            throw DiscordCommandError.wrongDateFormat(dateString, format: Utils.dateFormatter.dateFormat.uppercased())
        }
        guard let booking = await bookingsService.booking(at: date) else {
            throw DiscordCommandError.noBookingFoundAtDate(date)
        }
        
        // Only admins can delete bookings of other people
        if booking.author != user.id {
            let userPermissions = Permissions.shared.permissionsLevel(of: user.id, roles: member.roles)
            guard userPermissions == .admin else {
                throw DiscordCommandError.deleteBookingPermissionDenied(required: .admin)
            }
        }
        
        let bookingEmbed = try await Utils.createBookingEmbed(for: booking)
        await bookingsService.deleteBooking(booking)
        
        try await client.respond(
            token: interaction.token,
            payload: .init(
                content: "The following booking has been cancelled:",
                embeds: [bookingEmbed]
            )
        )
    }
}
