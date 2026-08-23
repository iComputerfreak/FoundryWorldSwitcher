//
//  DatePollCommand.swift
//

import DiscordBM
import Foundation
import Logging

struct DatePollCommand: DiscordCommand {
    private enum Constants {
        static let candidateSeparator = ","
    }

    let logger = Logger(label: String(describing: Self.self))
    let name = "datepoll"
    let description = "Creates and manages campaign date polls"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster

    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .subCommand,
            name: "create",
            description: "Creates a date poll for a campaign role",
            options: [
                .init(type: .role, name: "role", description: "Campaign role that must vote", required: true),
                .init(type: .string, name: "dates", description: "Comma-separated dates in DD.MM or DD.MM.YYYY format", required: true),
                .init(type: .string, name: "description", description: "Optional poll description", required: false),
                .init(type: .string, name: "deadline", description: "Optional voting deadline in DD.MM or DD.MM.YYYY format", required: false),
            ]
        ),
        .init(
            type: .subCommand,
            name: "finalize",
            description: "Finalizes a date poll",
            options: [
                .init(type: .string, name: "poll_id", description: "Poll ID", required: true),
                .init(type: .string, name: "date", description: "Chosen date in DD.MM or DD.MM.YYYY format", required: true),
            ]
        ),
        .init(
            type: .subCommand,
            name: "cancel",
            description: "Cancels a date poll",
            options: [
                .init(type: .string, name: "poll_id", description: "Poll ID", required: true),
            ]
        ),
    ]

    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        guard let subcommand = applicationCommand.options?.first else {
            throw DiscordCommandError.missingSubcommand
        }
        switch subcommand.name {
        case "create":
            try await createPoll(subcommand: subcommand, interaction: interaction, client: client)
        case "finalize":
            try await finalizePoll(subcommand: subcommand, interaction: interaction, client: client)
        case "cancel":
            try await cancelPoll(subcommand: subcommand, interaction: interaction, client: client)
        default:
            throw DiscordCommandError.missingSubcommand
        }
    }

    private func createPoll(
        subcommand: Interaction.ApplicationCommand.Option,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        guard
            let owner = interaction.member?.user,
            let guildID = interaction.guild_id,
            let channelID = interaction.channel_id
        else {
            throw DiscordCommandError.noGuild
        }
        let ownerID = owner.id

        let roleID = RoleSnowflake(try subcommand.requireOption(named: "role").requireString())
        let dates = try parseDates(try subcommand.requireOption(named: "dates").requireString())
        let description = subcommand.option(named: "description")?.value?.stringValue
        let deadline = try parseDeadline(subcommand.option(named: "deadline")?.value?.stringValue)
        let voters = try await requiredVoters(for: roleID, guildID: guildID, client: client)
        guard !voters.isEmpty else {
            throw DatePollError.invalidCandidates
        }

        let poll = await datePollsService.createPoll(
            ownerID: ownerID,
            ownerUsername: owner.username,
            guildID: guildID,
            channelID: channelID,
            campaignRoleID: roleID,
            requiredVoterIDs: voters,
            deadline: deadline,
            description: description,
            candidateDates: dates
        )
        try await client.respond(token: interaction.token, payload: DatePollRenderer.webhookPayload(for: poll))
        let message = try await client.getOriginalInteractionResponse(token: interaction.token).decode()
        try await datePollsService.publishPoll(id: poll.id, messageID: message.id)
    }

    private func finalizePoll(
        subcommand: Interaction.ApplicationCommand.Option,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        let pollID = try subcommand.requireOption(named: "poll_id").requireString().uppercased()
        let date = try parseDate(try subcommand.requireOption(named: "date").requireString())
        let poll = try await datePollsService.finalizePoll(id: pollID, date: date, userID: userID, roles: member.roles)
        try await updatePollMessage(for: poll, client: client)
        try await client.createMessage(
            channelId: poll.channelID,
            payload: .init(content: "\(DiscordUtils.mention(id: poll.campaignRoleID)) The session date has been finalized: **\(Utils.outputDateFormatter.string(from: date))**.")
        ).guardSuccess()
        try await client.respond(token: interaction.token, message: "Date poll `\(poll.id)` finalized.")
    }

    private func cancelPoll(
        subcommand: Interaction.ApplicationCommand.Option,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        let pollID = try subcommand.requireOption(named: "poll_id").requireString().uppercased()
        let poll = try await datePollsService.cancelPoll(id: pollID, userID: userID, roles: member.roles)
        try await updatePollMessage(for: poll, client: client)
        try await client.respond(token: interaction.token, message: "Date poll `\(poll.id)` cancelled.")
    }

    private func parseDates(_ value: String) throws -> [Date] {
        let dates = try value
            .split(separator: Constants.candidateSeparator)
            .map { try parseDate(String($0).trimmingCharacters(in: .whitespaces)) }
        guard !dates.isEmpty, dates.count <= 20, Set(dates).count == dates.count else {
            throw DatePollError.invalidCandidates
        }
        guard dates.allSatisfy({ Calendar.current.startOfDay(for: $0).addingTimeInterval(GlobalConstants.secondsPerDay) > .now }) else {
            throw DiscordCommandError.dateIsInThePast(dates.first ?? .now)
        }
        return dates
    }

    private func parseDate(_ value: String) throws -> Date {
        if let date = Utils.inputDateFormatter.date(from: value) {
            return date
        }

        let components = value
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .split(separator: ".", omittingEmptySubsequences: false)
        guard
            components.count == 2,
            let day = Int(components[0]),
            let month = Int(components[1])
        else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM or DD.MM.YYYY")
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        guard let thisYearDate = date(day: day, month: month, year: currentYear, calendar: calendar) else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM or DD.MM.YYYY")
        }
        if calendar.startOfDay(for: thisYearDate).addingTimeInterval(GlobalConstants.secondsPerDay) > .now {
            return thisYearDate
        }
        guard let nextYearDate = date(day: day, month: month, year: currentYear + 1, calendar: calendar) else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM or DD.MM.YYYY")
        }
        return nextYearDate
    }

    private func date(day: Int, month: Int, year: Int, calendar: Calendar) -> Date? {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        guard
            calendar.component(.day, from: date) == day,
            calendar.component(.month, from: date) == month,
            calendar.component(.year, from: date) == year
        else {
            return nil
        }
        return date
    }

    private func parseDeadline(_ value: String?) throws -> Date {
        let calendar = Calendar.current
        let date = try value.map(parseDate) ?? calendar.date(byAdding: .day, value: 7, to: .now)!
        let deadline = calendar.startOfDay(for: date).addingTimeInterval(GlobalConstants.secondsPerDay - 1)
        guard deadline > .now else {
            throw DiscordCommandError.dateIsInThePast(date)
        }
        return deadline
    }

    private func requiredVoters(
        for roleID: RoleSnowflake,
        guildID: GuildSnowflake,
        client: any DiscordClient
    ) async throws -> Set<UserSnowflake> {
        var voters: Set<UserSnowflake> = []
        var after: UserSnowflake?
        while true {
            let members = try await client.listGuildMembers(guildId: guildID, limit: 1_000, after: after).decode()
            for member in members {
                guard let user = member.user, user.bot != true, member.roles.contains(roleID) else { continue }
                voters.insert(user.id)
            }
            guard members.count == 1_000, let lastUserID = members.last?.user?.id else { break }
            after = lastUserID
        }
        return voters
    }

    private func updatePollMessage(for poll: DatePoll, client: any DiscordClient) async throws {
        guard let messageID = poll.messageID else { throw DatePollError.missingMessageReference }
        try await client.updateMessage(
            channelId: poll.channelID,
            messageId: messageID,
            payload: DatePollRenderer.messagePayload(for: poll)
        ).guardSuccess()
    }
}
