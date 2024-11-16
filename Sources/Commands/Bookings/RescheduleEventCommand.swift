//
//  File.swift
//  
//
//  Created by Jonas Frey on 19.04.24.
//

import DiscordBM
import Foundation
import Logging

struct RescheduleEventCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "rescheduleevent"
    let description = "Reschedules an event booking"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .string,
            name: "original_date",
            description: "The ID of the event to reschedule",
            required: true
        ),
        .init(
            type: .string,
            name: "new_date",
            description: "The new due date of the event",
            required: false
        ),
        .init(
            type: .string,
            name: "new_time",
            description: "The new time of the event",
            required: false
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        guard
            let member = interaction.member,
            let userID = member.user?.id
        else {
            throw DiscordCommandError.noUser
        }
        
        let eventDateString = try applicationCommand.requireOption(named: "original_date").requireString()
        guard let eventDate = Utils.inputDateFormatter.date(from: eventDateString) else {
            throw DiscordCommandError.wrongDateFormat(
                eventDateString,
                format: Utils.inputDateFormatter.dateFormat.uppercased()
            )
        }
        
        guard var booking = await bookingsService.booking(at: eventDate) else {
            throw DiscordCommandError.noBookingFoundAtDate(eventDate)
        }
        
        guard 
            booking.author == userID || Permissions.shared.permissionsLevel(of: userID, roles: member.roles) == .admin
        else {
            throw DiscordCommandError.rescheduleBookingPermissionDenied(required: .admin)
        }
        
        var newBookingDate: Date = booking.date
        if let newDateString = applicationCommand.option(named: "new_date")?.value?.stringValue {
            guard let newDate = Utils.inputDateFormatter.date(from: newDateString) else {
                throw DiscordCommandError.wrongDateFormat(
                    newDateString,
                    format: Utils.inputDateFormatter.dateFormat.uppercased()
                )
            }
            // Overwrite only the date
            newBookingDate = updateDate(of: newBookingDate, to: newDate)
        }
        if 
            booking is EventBooking, // only EventBookings have a time
            let newTimeString = applicationCommand.option(named: "new_time")?.value?.stringValue
        {
            guard let newTime = Utils.timeFormatter.date(from: newTimeString) else {
                throw DiscordCommandError.wrongTimeFormat(
                    newTimeString,
                    format: Utils.timeFormatter.dateFormat.uppercased()
                )
            }
            // Overwrite only the time
            newBookingDate = updateTime(of: newBookingDate, to: newTime)
        }
        
        // Save the new event date
        booking.date = newBookingDate
        // Delete and re-create to re-queue all new events
        await bookingsService.deleteBooking(booking)
        await bookingsService.createBooking(booking)
        
        try await client.respond(
            token: interaction.token,
            payload: .init(
                content: "Successfully rescheduled the event:",
                embeds: [Utils.createBookingEmbed(for: booking)]
            )
        )
    }
    
    /// Updates the day, month and year of the given date to the new date
    private func updateDate(of date: Date, to newDate: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let timeDuration = date.timeIntervalSince(startOfDay)
        
        return calendar.startOfDay(for: newDate).addingTimeInterval(timeDuration)
    }
    
    /// Updates the time of the given date to the time of the new date
    private func updateTime(of date: Date, to newDate: Date) -> Date {
        let calendar = Calendar.current
        let startOfNewDay = calendar.startOfDay(for: newDate)
        let timeDuration = newDate.timeIntervalSince(startOfNewDay)
        
        return calendar.startOfDay(for: date).addingTimeInterval(timeDuration)
    }
}
