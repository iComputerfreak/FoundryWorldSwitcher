//
//  DatePollRenderer.swift
//

import DiscordBM
import Foundation

enum DatePollRenderer {
    private enum Constants {
        static let componentPrefix = "datepoll"
        static let noAvailabilityValue = "none"
        static let maximumDisplayedMentions = 8
    }

    static func webhookPayload(for poll: DatePoll) -> Payloads.EditWebhookMessage {
        let content = contentAndComponents(for: poll)
        return .init(embeds: [content.embed], components: content.components)
    }

    static func messagePayload(for poll: DatePoll) -> Payloads.EditMessage {
        let content = contentAndComponents(for: poll)
        return .init(embeds: [content.embed], components: content.components)
    }

    static func interactionAction(from customID: String) -> (action: String, pollID: String)? {
        let parts = customID.split(separator: ":")
        guard parts.count == 3, parts[0] == Constants.componentPrefix else { return nil }
        return (String(parts[1]), String(parts[2]))
    }

    static func candidateIDs(from values: [String], poll: DatePoll) throws -> Set<UUID> {
        guard !values.isEmpty else { throw DatePollError.invalidCandidates }
        if values.contains(Constants.noAvailabilityValue) {
            guard values.count == 1 else { throw DatePollError.invalidCandidates }
            return []
        }
        let candidateIDs = Set(values.compactMap(UUID.init(uuidString:)))
        guard candidateIDs.count == values.count else { throw DatePollError.invalidCandidates }
        return candidateIDs
    }

    static func reminderComponents(for poll: DatePoll) -> [Interaction.ActionRow] {
        guard poll.deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) else { return [] }
        return [[.button(.init(
            style: .secondary,
            label: "Remind me tomorrow",
            custom_id: componentID(action: "delay", pollID: poll.id)
        ))]]
    }

    private static func contentAndComponents(for poll: DatePoll) -> (embed: Embed, components: [Interaction.ActionRow]) {
        let status = statusText(for: poll)
        let deadline = DiscordUtils.timestamp(date: poll.deadline, style: .relativeTime)
        var description = "Campaign: \(DiscordUtils.mention(id: poll.campaignRoleID))\n"
        description += "Poll ID: `\(poll.id)`\n"
        description += "Voting closes \(deadline).\n\n"
        if let pollDescription = poll.description, !pollDescription.isEmpty {
            description += "\(pollDescription.prefix(1_000))\n\n"
        }
        description += status

        let availability = poll.candidates.map { candidate in
            "\(Utils.outputDateFormatter.string(from: candidate.date)): \(poll.availableVoters(for: candidate).count) can attend"
        }.joined(separator: "\n")
        var fields = [Embed.Field(name: "Availability", value: String(availability.prefix(1_000)))]

        if poll.bestCandidates.isEmpty {
            fields.append(.init(name: "Current result", value: "No availability has been submitted yet."))
        } else {
            for candidate in poll.bestCandidates {
                fields.append(.init(
                    name: "Best date: \(Utils.outputDateFormatter.string(from: candidate.date))",
                    value: availabilitySummary(for: candidate, poll: poll)
                ))
            }
        }

        let noAvailability = poll.noAvailabilityVoterIDs
        if !noAvailability.isEmpty {
            fields.append(.init(name: "No date works", value: mentions(for: noAvailability)))
        }
        if !poll.outstandingVoterIDs.isEmpty {
            fields.append(.init(name: "Still waiting for", value: mentions(for: poll.outstandingVoterIDs)))
        }

        let embed = Embed(title: "Session date poll", description: description, fields: fields)
        return (embed, components(for: poll))
    }

    private static func components(for poll: DatePoll) -> [Interaction.ActionRow] {
        var options = poll.candidates.map { candidate in
            Interaction.ActionRow.StringSelectMenu.Option(
                label: Utils.outputDateFormatter.string(from: candidate.date),
                value: candidate.id.uuidString
            )
        }
        options.append(.init(label: "None of these dates", value: Constants.noAvailabilityValue))

        guard poll.isOpen else {
            return [[.stringSelect(.init(
                custom_id: componentID(action: "vote", pollID: poll.id),
                options: options,
                placeholder: "Voting is closed",
                min_values: 1,
                max_values: options.count,
                disabled: true
            ))]]
        }

        var rows: [Interaction.ActionRow] = [[.stringSelect(.init(
            custom_id: componentID(action: "vote", pollID: poll.id),
            options: options,
            placeholder: "Select every date you can attend",
            min_values: 1,
            max_values: options.count
        ))]]

        if poll.deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) {
            rows.append([.button(.init(
                style: .secondary,
                label: "Remind me",
                custom_id: componentID(action: "remind", pollID: poll.id)
            ))])
        }
        return rows
    }

    private static func statusText(for poll: DatePoll) -> String {
        switch poll.status {
        case .open:
            return "\(poll.votes.count)/\(poll.requiredVoterIDs.count) members have voted."
        case .awaitingFinalization:
            return "Voting has closed. A Dungeon Master will finalize a date."
        case .finalized:
            guard let candidateID = poll.finalizedCandidateID, let candidate = poll.candidate(id: candidateID) else {
                return "This poll has been finalized."
            }
            return "Finalized date: **\(Utils.outputDateFormatter.string(from: candidate.date))**."
        case .cancelled:
            return "This poll was cancelled."
        }
    }

    private static func availabilitySummary(for candidate: DatePollCandidate, poll: DatePoll) -> String {
        if poll.availableVoters(for: candidate).count == poll.requiredVoterIDs.count {
            return "Everyone can attend."
        }
        let unavailable = poll.unavailableVoters(for: candidate)
        let outstanding = poll.outstandingVoterIDs
        var summary = unavailable.isEmpty ? "No submitted unavailability." : "Cannot attend: \(mentions(for: unavailable))"
        if !outstanding.isEmpty {
            summary += "\nStill waiting: \(mentions(for: outstanding))"
        }
        return summary
    }

    private static func mentions(for users: [UserSnowflake]) -> String {
        let displayedUsers = users.prefix(Constants.maximumDisplayedMentions)
        var result = displayedUsers.map(DiscordUtils.mention(id:)).joined(separator: ", ")
        let remaining = users.count - displayedUsers.count
        if remaining > 0 {
            result += " and \(remaining) more"
        }
        return result
    }

    private static func componentID(action: String, pollID: String) -> String {
        "\(Constants.componentPrefix):\(action):\(pollID)"
    }
}
