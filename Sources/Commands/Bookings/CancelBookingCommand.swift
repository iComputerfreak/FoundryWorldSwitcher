//
//  CancelBookingCommand.swift
//
//
//  Created by Jonas Frey on 14.04.24.
//

import DiscordBM
import Foundation
import Logging

struct CancelBookingCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: CancelBookingCommand.self))
    let name = "cancelbooking"
    let description = "Cancels a booking on a specified date"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    
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
        guard let booking = await context.bookings.booking(at: date) else {
            throw DiscordCommandError.noBookingFoundAtDate(date)
        }
        guard context.config.foundryFeaturesEnabled || booking.worldID == nil else {
            throw DiscordCommandError.foundryFeaturesDisabled
        }
        
        // Only admins can delete bookings of other people
        if booking.author != user.id {
            let userPermissions = context.permissions.permissionsLevel(of: user.id, roles: member.roles)
            guard userPermissions == .admin else {
                throw DiscordCommandError.cancelBookingPermissionDenied(required: .admin)
            }
        }
        
        let bookingEmbed = try await Utils.createBookingEmbed(for: booking)
        
        await context.bookings.cancelBooking(id: booking.id)
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
                content: "The following booking has been cancelled:",
                embeds: [bookingEmbed]
            )
        )
    }
}
