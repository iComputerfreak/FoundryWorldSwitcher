//
//  BookCommand.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation
import Logging

struct BookCommand: DiscordCommand {
    private enum Constants {
        static let dateFormat = "dd.MM.yyyy"
        static let timeFormat = "HH:mm"
        static let dateTimeFormatSeparator = "_"
    }
    
    static let dateFormatter = {
        let f = DateFormatter()
        f.dateFormat = Constants.dateFormat
        return f
    }()
    
    static let dateTimeFormatter = {
        let f = DateFormatter()
        f.dateFormat = "\(Constants.dateFormat)\(Constants.dateTimeFormatSeparator)\(Constants.timeFormat)"
        return f
    }()
    
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "book"
    let description = "Books a reservation or event"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    
    private static let worldOption = ApplicationCommand.Option(
        type: .string,
        name: "world",
        description: "The world ID of the world to book",
        required: true
    )
    
    private static let dateOption = ApplicationCommand.Option(
        type: .string,
        name: "date",
        description: "The date of the event or reservation in the format 'DD.MM.YYYY'",
        required: true
    )
    
    private static let timeOption = ApplicationCommand.Option(
        type: .string,
        name: "time",
        description: "The time of the event or reservation in the format 'HH:MM'",
        required: true
    )
    
    private static let locationOption = ApplicationCommand.Option(
        type: .channel,
        name: "location",
        description: "The location of the event",
        required: true,
        channel_types: [.guildVoice]
    )
    
    private static let topicOption = ApplicationCommand.Option(
        type: .string,
        name: "topic",
        description: "The topic of the event, e.g., 'Session 12'",
        required: true
    )
    
    private static let campaignRoleOption = ApplicationCommand.Option(
        type: .role,
        name: "role",
        description: "The role that participates in this event",
        required: true
    )
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .subCommand,
            name: "reservation",
            description: "Books a reservation",
            options: [
                worldOption,
                dateOption,
            ]
        ),
        .init(
            type: .subCommand,
            name: "event",
            description: "Books an event",
            options: [
                worldOption,
                dateOption,
                timeOption,
                locationOption,
                topicOption,
                campaignRoleOption
            ]
        )
    ]
    
    func handle(_ applicationCommand: Interaction.ApplicationCommand, interaction: Interaction, client: any DiscordClient) async throws {
        guard let userID = interaction.member?.user?.id else {
            throw DiscordBotError.noUser
        }
        guard let subcommand = applicationCommand.options?.first else {
            throw DiscordCommandError.missingSubcommand
        }
        
        // MARK: Common arguments
        let world = try await parseWorld(from: subcommand, optionName: Self.worldOption.name)
        let dateString = try subcommand.requireOption(named: Self.dateOption.name).requireString()
        guard
            let date = Self.dateFormatter.date(from: dateString),
            // The day should be either today or in the future
            Calendar.current.startOfDay(for: date).addingTimeInterval(GlobalConstants.secondsPerDay) > .now
        else {
            throw DiscordCommandError.wrongDateFormat(dateString, format: Constants.dateFormat.uppercased())
        }
        
        guard await bookingsService.booking(at: date) == nil else {
            throw DiscordCommandError.bookingAlreadyExists(atDate: date)
        }
        
        var warning: String?
        
        // MARK: Create the Booking
        let booking: any Booking
        if let eventSubcommand = applicationCommand.option(named: "event") {
            let timeString = try eventSubcommand.requireOption(named: Self.timeOption.name).requireString()
            let role = try eventSubcommand.requireOption(named: Self.campaignRoleOption.name).requireString()
            let location = try eventSubcommand.requireOption(named: Self.locationOption.name).requireString()
            let topic = try eventSubcommand.requireOption(named: Self.topicOption.name).requireString()
            guard let dateTime = Self.dateTimeFormatter.date(from: "\(dateString)\(Constants.dateTimeFormatSeparator)\(timeString)") else {
                throw DiscordCommandError.wrongTimeFormat(timeString, format: Constants.timeFormat.uppercased())
            }
            
            booking = EventBooking(
                date: dateTime,
                author: userID,
                worldID: world.id,
                campaignRoleSnowflake: RoleSnowflake(role),
                location: ChannelSnowflake(location),
                topic: topic
            )
            if booking.date > booking.bookingIntervalEndDate {
                let start = DiscordUtils.timestamp(date: booking.bookingIntervalStartDate, style: .shortDateTime)
                let end = DiscordUtils.timestamp(date: booking.bookingIntervalEndDate, style: .shortDateTime)
                warning = "\nThe world will be locked from \(start) to \(end).\n" +
                "**Warning**: With the current configuration settings, the world will be unlocked before the event starts."
            }
        } else {
            booking = ReservationBooking(date: date, author: userID, worldID: world.id)
        }
        
        // MARK: Create the booking
        await bookingsService.createBooking(booking)
        
        // MARK: Respond to the user
        try await client.respond(
            token: interaction.token,
            payload: .init(
                content: "Booking created successfully.\(warning ?? "")",
                embeds: [Utils.createBookingEmbed(for: booking)]
            )
        )
    }
}
