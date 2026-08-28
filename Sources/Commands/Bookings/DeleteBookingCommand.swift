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
    let description = "Deletes a dated booking, including its session-log record"
    let permissionsLevel: BotPermissionLevel = .admin
    
    let options: [ApplicationCommand.Option]? = [
        ApplicationCommand.Option(
            type: .string,
            name: "date",
            description: "Booking date in DD.MM.YYYY format",
            required: true
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        guard let dateString = try applicationCommand.option(named: "date")?.requireString() else {
            throw DiscordCommandError.missingArgument(argumentName: "date")
        }
        guard let date = Utils.inputDateFormatter.date(from: dateString) else {
            throw DiscordCommandError.wrongDateFormat(dateString, format: Utils.inputDateFormatter.dateFormat.uppercased())
        }
        guard let booking = await context.bookings.booking(at: date) else {
            throw DiscordCommandError.noBookingFoundAtDate(date)
        }
        guard context.config.foundryFeaturesEnabled || booking.worldID == nil else {
            throw DiscordCommandError.foundryFeaturesDisabled
        }
        
        let bookingEmbed = try await Utils.createBookingEmbed(for: booking)
        
        await context.bookings.deleteBooking(booking)
        await presenceService.refresh()
        let updatedPolls = await context.datePolls.reconcileBookingLinks(bookings: await context.bookings.allBookings)
        await DatePollMessageSynchronizer.synchronize(
            updatedPolls,
            datePolls: context.datePolls,
            foundryFeaturesEnabled: context.config.foundryFeaturesEnabled,
            client: client
        )
        
        try await client.respond(
            token: interaction.token,
            payload: .init(
                content: "The following booking has been deleted and removed from the session log:",
                embeds: [bookingEmbed]
            )
        )
    }
}
