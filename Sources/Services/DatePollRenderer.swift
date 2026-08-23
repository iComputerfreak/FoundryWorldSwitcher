//
//  DatePollRenderer.swift
//

import DiscordBM
import Foundation

enum DatePollRenderer {
    private enum Constants {
        static let componentPrefix = "datepoll"
        static let maximumDisplayedMentions = 8
        static let checkboxGroupSize = 10
    }

    static func webhookPayload(for poll: DatePoll) -> Payloads.EditWebhookMessage {
        .init(componentsV2: pollComponents(for: poll))
    }

    static func messagePayload(for poll: DatePoll) -> Payloads.EditMessage {
        .init(componentsV2: pollComponents(for: poll))
    }

    static func interactionAction(from customID: String) -> (action: String, pollID: String)? {
        let parts = customID.split(separator: ":")
        guard parts.count == 3, parts[0] == Constants.componentPrefix else { return nil }
        return (String(parts[1]), String(parts[2]))
    }

    static func availabilityModal(for poll: DatePoll, voterID: UserSnowflake) -> Payloads.InteractionResponse {
        let selectedCandidateIDs = poll.votes[voterID]?.candidateIDs ?? []
        let candidates = orderedCandidates(for: poll)
        var components = stride(from: 0, to: candidates.count, by: Constants.checkboxGroupSize).enumerated().map { index, start in
            let candidates = candidates[start..<min(start + Constants.checkboxGroupSize, candidates.count)]
            let options = candidates.map { candidate in
                Interaction.ActionRow.CheckboxGroup.Option(
                    value: candidate.id.uuidString,
                    label: Utils.outputDateFormatter.string(from: candidate.date),
                    default: selectedCandidateIDs.contains(candidate.id)
                )
            }
            let group = Interaction.ActionRow.CheckboxGroup(
                custom_id: checkboxGroupID(pollID: poll.id, index: index),
                options: options,
                min_values: 0,
                max_values: options.count,
                required: false
            )
            return Interaction.ModalComponent.label(.init(
                label: index == 0 ? "Dates you can attend" : "Additional dates",
                description: "Select every date that works for you.",
                component: .checkboxGroup(group)
            ))
        }
        components.append(.label(.init(
            label: "No dates work",
            component: .checkbox(.init(
                custom_id: unavailableCheckboxID(pollID: poll.id),
                default: poll.votes[voterID] != nil && selectedCandidateIDs.isEmpty
            ))
        )))
        return .modal(.init(custom_id: componentID(action: "vote", pollID: poll.id), title: "Set availability", componentsV2: components))
    }

    static func candidateIDs(from modal: Interaction.ModalSubmit, poll: DatePoll) throws -> Set<UUID> {
        guard let components = modal.componentsV2 else { throw DatePollError.invalidCandidates }
        let expectedGroupIDs = Set(stride(from: 0, to: poll.candidates.count, by: Constants.checkboxGroupSize).enumerated().map {
            checkboxGroupID(pollID: poll.id, index: $0.offset)
        })
        var receivedGroupIDs: Set<String> = []
        var candidateIDs: Set<UUID> = []
        var isUnavailable = false

        for component in components {
            guard case let .label(label) = component else {
                throw DatePollError.invalidCandidates
            }
            switch label.component {
            case let .checkboxGroup(group):
                guard expectedGroupIDs.contains(group.custom_id), receivedGroupIDs.insert(group.custom_id).inserted else {
                    throw DatePollError.invalidCandidates
                }
                let values = group.values ?? []
                let selectedCandidateIDs = Set(values.compactMap(UUID.init(uuidString:)))
                guard selectedCandidateIDs.count == values.count else { throw DatePollError.invalidCandidates }
                candidateIDs.formUnion(selectedCandidateIDs)
            case let .checkbox(checkbox):
                guard checkbox.custom_id == unavailableCheckboxID(pollID: poll.id) else {
                    throw DatePollError.invalidCandidates
                }
                isUnavailable = checkbox.value ?? false
            default:
                throw DatePollError.invalidCandidates
            }
        }

        guard receivedGroupIDs == expectedGroupIDs else { throw DatePollError.invalidCandidates }
        if isUnavailable && candidateIDs.isEmpty {
            return []
        }
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

    private static func pollComponents(for poll: DatePoll) -> [Interaction.MessageLayoutComponent] {
        var components: [Interaction.MessageLayoutComponent] = [
            .textDisplay(.init(content: "**Session date poll · \(DiscordUtils.mention(id: poll.campaignRoleID))**"))
        ]
        if let description = poll.description, !description.isEmpty {
            components.append(.textDisplay(.init(content: String(description.prefix(1_000)))))
        }

        components += [
            .textDisplay(.init(content: participationSummary(for: poll))),
            .separator(.init(divider: true, spacing: .small)),
        ]

        let candidates = orderedCandidates(for: poll)
        for startIndex in stride(from: 0, to: candidates.count, by: 3) {
            let dateCards = candidates[startIndex..<min(startIndex + 3, candidates.count)].map { candidate in
                Interaction.MessageLayoutComponent.textDisplay(.init(content: dateCard(for: candidate, poll: poll)))
            }
            components.append(.container(.init(componentsV2: dateCards)))
        }

        components.append(.actionRow(controls(for: poll)))
        components.append(.textDisplay(.init(content: "-# Created by \(poll.ownerUsername ?? "unknown") · Poll ID `\(poll.id)`")))
        components.append(.textDisplay(.init(content: "-# Voting closes \(DiscordUtils.timestamp(date: poll.deadline, style: .relativeTime))")))
        return components
    }

    private static func controls(for poll: DatePoll) -> Interaction.ActionRow {
        guard poll.isOpen else {
            return [.button(.init(
                style: .secondary,
                label: "Voting is closed",
                custom_id: componentID(action: "vote", pollID: poll.id),
                disabled: true
            ))]
        }

        var buttons: [Interaction.ActionRow.Component] = [.button(.init(
            style: .primary,
            label: "Set availability",
            custom_id: componentID(action: "vote", pollID: poll.id)
        ))]

        if poll.deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) {
            buttons.append(.button(.init(
                style: .secondary,
                label: "Remind me",
                custom_id: componentID(action: "remind", pollID: poll.id)
            )))
        }
        return .init(components: buttons)
    }

    private static func participationSummary(for poll: DatePoll) -> String {
        switch poll.status {
        case .open:
            var summary = "## Current availability\n**\(poll.votes.count)/\(poll.requiredVoterIDs.count)** members have voted."
            if poll.bestCandidates.isEmpty {
                summary += "\nNo leading date yet."
            } else {
                let dates = poll.bestCandidates
                    .sorted { $0.date < $1.date }
                    .map { Utils.outputDateFormatter.string(from: $0.date) }
                    .joined(separator: ", ")
                summary += "\nLeading: **\(dates)**."
            }
            if !poll.noAvailabilityVoterIDs.isEmpty {
                summary += "\nNo dates work: \(mentions(for: poll.noAvailabilityVoterIDs))"
            }
            return summary
        case .awaitingFinalization:
            return "## Voting closed\nA Dungeon Master will finalize a date."
        case .finalized:
            guard let candidateID = poll.finalizedCandidateID, let candidate = poll.candidate(id: candidateID) else {
                return "## Finalized\nThis poll has been finalized."
            }
            return "## Finalized\n**\(Utils.outputDateFormatter.string(from: candidate.date))** is the session date."
        case .cancelled:
            return "## Cancelled\nThis poll was cancelled."
        }
    }

    private static func dateCard(for candidate: DatePollCandidate, poll: DatePoll) -> String {
        let isLeading = poll.bestCandidates.contains(where: { $0.id == candidate.id })
        var card = "### \(Utils.outputDateFormatter.string(from: candidate.date))"
        if isLeading {
            card += " · Leading"
        }
        card += "\n**\(poll.availableVoters(for: candidate).count)/\(poll.requiredVoterIDs.count)** can attend"

        if poll.availableVoters(for: candidate).count == poll.requiredVoterIDs.count {
            return card + "\nEveryone can attend."
        }
        let unavailable = poll.unavailableVoters(for: candidate)
        let outstanding = poll.outstandingVoterIDs
        card += unavailable.isEmpty ? "\nNo submitted unavailability." : "\nCannot attend: \(mentions(for: unavailable))"
        if !outstanding.isEmpty {
            card += "\nWaiting: \(mentions(for: outstanding))"
        }
        return card
    }

    private static func orderedCandidates(for poll: DatePoll) -> [DatePollCandidate] {
        poll.candidates.sorted { $0.date < $1.date }
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

    private static func checkboxGroupID(pollID: String, index: Int) -> String {
        "\(Constants.componentPrefix):choices:\(pollID):\(index)"
    }

    private static func unavailableCheckboxID(pollID: String) -> String {
        "\(Constants.componentPrefix):unavailable:\(pollID)"
    }
}
