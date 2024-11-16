//
//  DeleteBookingCommand.swift
//
//
//  Created by Jonas Frey on 16.11.24.
//

import DiscordBM
import Foundation
import Logging

struct DeleteBookingCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: DeleteBookingCommand.self))
    let name = "deletebooking"
    let description = "Deletes a booking for a specific date, removing it from the session log as well."
    let permissionsLevel: BotPermissionLevel = .admin
    
    let options: [ApplicationCommand.Option]? = [
        ApplicationCommand.Option(
            type: .string,
            name: "date",
            description: "The date of the booking to delete",
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
        guard let date = Utils.inputDateFormatter.date(from: dateString) else {
            throw DiscordCommandError.wrongDateFormat(dateString, format: Utils.inputDateFormatter.dateFormat.uppercased())
        }
        guard let booking = await bookingsService.booking(at: date) else {
            throw DiscordCommandError.noBookingFoundAtDate(date)
        }
        
        let bookingEmbed = try await Utils.createBookingEmbed(for: booking)
        
        // MARK: Delete the booking
        // If the booking already started, we have to unlock world switching as well.
        if booking.bookingIntervalStartDate < .now && .now < booking.bookingIntervalEndDate {
            try WorldLockService.shared.unlockWorldSwitching()
        }
        await bookingsService.deleteBooking(booking)
        
        try await client.respond(
            token: interaction.token,
            payload: .init(
                content: "The following booking has been deleted and removed from the session log:",
                embeds: [bookingEmbed]
            )
        )
    }
}
