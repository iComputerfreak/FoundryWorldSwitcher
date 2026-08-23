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

    static func createMessagePayload(for poll: DatePoll) -> Payloads.CreateMessage {
        .init(componentsV2: pollComponents(for: poll))
    }

    static func creationModal() -> Payloads.InteractionResponse {
        .modal(.init(
            custom_id: DatePollCreationForm.modalID,
            title: "Create date poll",
            componentsV2: [
                .label(.init(
                    label: "Campaign role",
                    component: .roleSelect(.init(
                        custom_id: DatePollCreationForm.roleID,
                        placeholder: "Select campaign role",
                        max_values: 1,
                        required: true
                    ))
                )),
                .label(.init(
                    label: "Candidate dates",
                    description: "One DD.MM or DD.MM.YYYY date per line.",
                    component: .textInput(.init(
                        custom_id: DatePollCreationForm.datesID,
                        style: .paragraph,
                        max_length: 500,
                        required: true,
                        placeholder: "12.09\n19.09\n26.09"
                    ))
                )),
                .label(.init(
                    label: "Description",
                    description: "Optional details for the campaign.",
                    component: .textInput(.init(
                        custom_id: DatePollCreationForm.descriptionID,
                        style: .paragraph,
                        max_length: 1_000,
                        required: false
                    ))
                )),
                .label(.init(
                    label: "Deadline days",
                    description: "Whole days from now, from 1 to 60.",
                    component: .textInput(.init(
                        custom_id: DatePollCreationForm.deadlineDaysID,
                        style: .short,
                        max_length: 2,
                        required: true,
                        value: "7"
                    ))
                )),
            ]
        ))
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
                    label: displayDate(candidate.date),
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

    static func finalizationModal(for poll: DatePoll) -> Payloads.InteractionResponse {
        let candidates = orderedCandidates(for: poll)
        let components = stride(from: 0, to: candidates.count, by: Constants.checkboxGroupSize).enumerated().map { index, start in
            let candidates = candidates[start..<min(start + Constants.checkboxGroupSize, candidates.count)]
            let options = candidates.map { candidate in
                Interaction.ActionRow.CheckboxGroup.Option(
                    value: candidate.id.uuidString,
                    label: "\(displayDate(candidate.date)) · \(availabilityIcon(for: candidate, poll: poll)) \(poll.availableVoters(for: candidate).count)/\(poll.votes.count) available"
                )
            }
            return Interaction.ModalComponent.label(.init(
                label: index == 0 ? "Final session date" : "Additional dates",
                description: "Select exactly one date.",
                component: .checkboxGroup(.init(
                    custom_id: finalizationCheckboxGroupID(pollID: poll.id, index: index),
                    options: options,
                    min_values: 0,
                    max_values: options.count,
                    required: false
                ))
            ))
        }
        return .modal(.init(custom_id: componentID(action: "finalize", pollID: poll.id), title: "Finalize date", componentsV2: components))
    }

    static func finalizationCandidateID(from modal: Interaction.ModalSubmit, poll: DatePoll) throws -> UUID {
        guard let components = modal.componentsV2 else { throw DatePollError.invalidFinalizationSelection }
        let expectedGroupIDs = Set(stride(from: 0, to: poll.candidates.count, by: Constants.checkboxGroupSize).enumerated().map {
            finalizationCheckboxGroupID(pollID: poll.id, index: $0.offset)
        })
        var receivedGroupIDs: Set<String> = []
        var candidateIDs: Set<UUID> = []

        for component in components {
            guard case let .label(label) = component, case let .checkboxGroup(group) = label.component else {
                throw DatePollError.invalidFinalizationSelection
            }
            guard expectedGroupIDs.contains(group.custom_id), receivedGroupIDs.insert(group.custom_id).inserted else {
                throw DatePollError.invalidFinalizationSelection
            }
            let values = group.values ?? []
            let selectedCandidateIDs = Set(values.compactMap(UUID.init(uuidString:)))
            guard selectedCandidateIDs.count == values.count else { throw DatePollError.invalidFinalizationSelection }
            candidateIDs.formUnion(selectedCandidateIDs)
        }

        guard receivedGroupIDs == expectedGroupIDs, candidateIDs.count == 1, let candidateID = candidateIDs.first else {
            throw DatePollError.invalidFinalizationSelection
        }
        return candidateID
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
            .textDisplay(.init(content: "# Session date poll · \(DiscordUtils.mention(id: poll.campaignRoleID))"))
        ]
        if let description = poll.description, !description.isEmpty {
            components.append(.textDisplay(.init(content: String(description.prefix(1_000)))))
        }

        components.append(.textDisplay(.init(content: participationSummary(for: poll))))

        if poll.status != .cancelled {
            if let leadingCandidate = poll.bestCandidates.sorted(by: { $0.date < $1.date }).first {
                components.append(.container(.init(componentsV2: [
                    .textDisplay(.init(content: dateCard(for: leadingCandidate, poll: poll)))
                ], accent_color: leadingAccentColor(for: leadingCandidate, poll: poll))))
            }

            components.append(.separator(.init(divider: true, spacing: .large)))

            let candidates = orderedCandidates(for: poll)
            let dateCards = candidates.map { candidate in
                Interaction.MessageLayoutComponent.textDisplay(.init(content: dateCard(for: candidate, poll: poll)))
            }
            components.append(.container(.init(componentsV2: dateCards)))
        }

        components.append(.actionRow(controls(for: poll)))
        var footer = "-# Created by \(poll.ownerUsername ?? "unknown") · Poll ID `\(poll.id)`"
        if poll.status != .cancelled && poll.status != .finalized {
            footer += " · Voting closes \(DiscordUtils.timestamp(date: poll.deadline, style: .relativeTime))"
        }
        components.append(.textDisplay(.init(content: footer)))
        return components
    }

    private static func controls(for poll: DatePoll) -> Interaction.ActionRow {
        var buttons: [Interaction.ActionRow.Component] = []

        if poll.isOpen {
            buttons.append(.button(.init(
                style: .primary,
                label: "Set availability",
                custom_id: componentID(action: "vote", pollID: poll.id)
            )))
        }

        if poll.isOpen, poll.deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) {
            buttons.append(.button(.init(
                style: .secondary,
                label: "Remind me",
                custom_id: componentID(action: "remind", pollID: poll.id)
            )))
        }

        if (poll.status == .open || poll.status == .awaitingFinalization), !poll.votes.isEmpty {
            buttons.append(.button(.init(
                style: .success,
                label: "Finalize",
                custom_id: componentID(action: "finalize", pollID: poll.id)
            )))
        }

        if poll.status == .open || poll.status == .awaitingFinalization {
            buttons.append(.button(.init(
                style: .danger,
                label: "Cancel",
                custom_id: componentID(action: "cancel", pollID: poll.id)
            )))
        }

        if buttons.isEmpty {
            return [.button(.init(
                style: .secondary,
                label: "Poll is closed",
                custom_id: componentID(action: "vote", pollID: poll.id),
                disabled: true
            ))]
        }
        return .init(components: buttons)
    }

    private static func participationSummary(for poll: DatePoll) -> String {
        switch poll.status {
        case .open:
            var summary = "## Current availability\n**\(poll.votes.count)/\(poll.requiredVoterIDs.count)** members have voted."
            if !poll.outstandingVoterIDs.isEmpty {
                summary += "\nWaiting: \(mentions(for: poll.outstandingVoterIDs))"
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
            return "## Finalized\n**\(displayDate(candidate.date))** is the session date."
        case .cancelled:
            return "## Cancelled\nThis poll was cancelled."
        }
    }

    private static func dateCard(for candidate: DatePollCandidate, poll: DatePoll) -> String {
        let isLeading = poll.bestCandidates.contains(where: { $0.id == candidate.id })
        var card = "### \(displayDate(candidate.date))"
        if isLeading {
            card += " · Leading"
        }
        let voters = poll.votes.count
        let attendees = poll.availableVoters(for: candidate)

        if voters == 0 {
            return card + "\nNo votes yet."
        }
        if attendees.isEmpty {
            return card + "\n❌ No one can attend."
        }
        if attendees.count == voters {
            return card + "\n✅ Everyone can attend."
        }
        return card + "\n👥 \(mentions(for: attendees)) can attend."
    }

    private static func leadingAccentColor(for candidate: DatePollCandidate, poll: DatePoll) -> DiscordColor {
        let attendees = poll.availableVoters(for: candidate)
        if attendees.isEmpty {
            return 0xED4245
        }
        if attendees.count == poll.votes.count {
            return 0x57F287
        }
        return 0xFEE75C
    }

    private static func availabilityIcon(for candidate: DatePollCandidate, poll: DatePoll) -> String {
        let attendees = poll.availableVoters(for: candidate).count
        if attendees == 0 {
            return "❌"
        }
        if attendees == poll.votes.count {
            return "✅"
        }
        return "👥"
    }

    private static func orderedCandidates(for poll: DatePoll) -> [DatePollCandidate] {
        poll.candidates.sorted { $0.date < $1.date }
    }

    static func displayDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).year())
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

    private static func finalizationCheckboxGroupID(pollID: String, index: Int) -> String {
        "\(Constants.componentPrefix):finalizechoices:\(pollID):\(index)"
    }
}
