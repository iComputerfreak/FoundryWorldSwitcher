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

    static func webhookPayload(for poll: DatePoll, foundryFeaturesEnabled: Bool, localization: LocalizationContext) -> Payloads.EditWebhookMessage {
        .init(componentsV2: pollComponents(for: poll, foundryFeaturesEnabled: foundryFeaturesEnabled, localization: localization))
    }

    static func messagePayload(for poll: DatePoll, foundryFeaturesEnabled: Bool, localization: LocalizationContext) -> Payloads.EditMessage {
        .init(componentsV2: pollComponents(for: poll, foundryFeaturesEnabled: foundryFeaturesEnabled, localization: localization))
    }

    static func createMessagePayload(for poll: DatePoll, foundryFeaturesEnabled: Bool, localization: LocalizationContext) -> Payloads.CreateMessage {
        .init(
            nonce: poll.publicationNonce.map(StringOrInt.string),
            componentsV2: pollComponents(for: poll, foundryFeaturesEnabled: foundryFeaturesEnabled, localization: localization),
            enforce_nonce: poll.publicationNonce == nil ? nil : true
        )
    }

    static func creationModal(localization: LocalizationContext) -> Payloads.InteractionResponse {
        .modal(.init(
            custom_id: DatePollCreationForm.modalID,
            title: localization.string("date_poll.creation.title", table: "DatePoll"),
            componentsV2: pollFormComponents(localization: localization)
        ))
    }

    static func editModal(for poll: DatePoll, localization: LocalizationContext) -> Payloads.InteractionResponse {
        .modal(.init(
            custom_id: componentID(action: .edit, pollID: poll.id),
            title: localization.string("date_poll.edit.title", table: "DatePoll"),
            componentsV2: pollFormComponents(for: poll, localization: localization)
        ))
    }

    private static func pollFormComponents(for poll: DatePoll? = nil, localization: LocalizationContext) -> [Interaction.ModalComponent] {
        let selectedRepeatInterval = String(poll?.repeatIntervalWeeks ?? 0)
        let inputDateFormatter = DateFormatter()
        inputDateFormatter.locale = localization.locale
        inputDateFormatter.calendar = .current
        inputDateFormatter.timeZone = .current
        inputDateFormatter.dateFormat = "dd.MM.yyyy"
        let candidateDates = poll.map {
            $0.candidates.map { inputDateFormatter.string(from: $0.date) }.joined(separator: "\n")
        }
        let deadlineDays = poll.map {
            String(max(1, min(60, Int(ceil($0.deadline.timeIntervalSinceNow / GlobalConstants.secondsPerDay)))))
        } ?? "7"
        return [
                .label(.init(
                    label: localization.string("date_poll.form.campaign_role.label", table: "DatePoll"),
                    component: .roleSelect(.init(
                        custom_id: DatePollCreationForm.roleID,
                        placeholder: localization.string("date_poll.form.campaign_role.placeholder", table: "DatePoll"),
                        default_values: poll.map { [.init(id: $0.campaignRoleID)] },
                        min_values: poll == nil ? 0 : 1,
                        max_values: 1,
                        required: poll != nil
                    ))
                )),
                .label(.init(
                    label: localization.string("date_poll.form.candidate_dates.label", table: "DatePoll"),
                    description: localization.string("date_poll.form.candidate_dates.description", table: "DatePoll"),
                    component: .textInput(.init(
                        custom_id: DatePollCreationForm.datesID,
                        style: .paragraph,
                        max_length: 500,
                        required: true,
                        value: candidateDates,
                        placeholder: "12.09\n19.09\n26.09"
                    ))
                )),
                .label(.init(
                    label: localization.string("date_poll.form.description.label", table: "DatePoll"),
                    description: localization.string("date_poll.form.description.description", table: "DatePoll"),
                    component: .textInput(.init(
                        custom_id: DatePollCreationForm.descriptionID,
                        style: .paragraph,
                        max_length: 1_000,
                        required: false,
                        value: poll?.description
                    ))
                )),
                .label(.init(
                    label: localization.string("date_poll.form.deadline_days.label", table: "DatePoll"),
                    description: localization.string("date_poll.form.deadline_days.description", table: "DatePoll"),
                    component: .textInput(.init(
                        custom_id: DatePollCreationForm.deadlineDaysID,
                        style: .short,
                        max_length: 2,
                        required: true,
                        value: deadlineDays
                    ))
                )),
                .label(.init(
                    label: localization.string("date_poll.form.repeat_interval.label", table: "DatePoll"),
                    description: localization.string("date_poll.form.repeat_interval.description", table: "DatePoll"),
                    component: .stringSelect(.init(
                        custom_id: DatePollCreationForm.repeatIntervalID,
                        options: [
                            .init(label: localization.string("date_poll.repeat.none", table: "DatePoll"), value: "0", default: selectedRepeatInterval == "0"),
                            .init(label: localization.string("date_poll.repeat.every_week", table: "DatePoll"), value: "1", default: selectedRepeatInterval == "1"),
                            .init(label: localization.string("date_poll.repeat.every_two_weeks", table: "DatePoll"), value: "2", default: selectedRepeatInterval == "2"),
                            .init(label: localization.string("date_poll.repeat.every_three_weeks", table: "DatePoll"), value: "3", default: selectedRepeatInterval == "3"),
                            .init(label: localization.string("date_poll.repeat.every_four_weeks", table: "DatePoll"), value: "4", default: selectedRepeatInterval == "4"),
                        ],
                        placeholder: localization.string("date_poll.repeat.none", table: "DatePoll"),
                        min_values: 1,
                        max_values: 1,
                        required: true
                    ))
                )),
            ]
    }

    static func interactionAction(from customID: String) -> (action: DatePollAction, pollID: String, candidateID: UUID?)? {
        let parts = customID.split(separator: ":")
        guard (parts.count == 3 || parts.count == 4), parts[0] == Constants.componentPrefix else { return nil }
        guard let action = DatePollAction(rawValue: String(parts[1])) else { return nil }
        if parts.count == 3 {
            return (action, String(parts[2]), nil)
        }
        guard parts.count == 4, action == .book, let candidateID = UUID(uuidString: String(parts[3])) else {
            return nil
        }
        return (action, String(parts[2]), candidateID)
    }

    static func availabilityModal(for poll: DatePoll, voterID: UserSnowflake, localization: LocalizationContext) -> Payloads.InteractionResponse {
        let selectedCandidateIDs = poll.votes[voterID]?.candidateIDs ?? []
        let candidates = orderedCandidates(for: poll)
        var components = stride(from: 0, to: candidates.count, by: Constants.checkboxGroupSize).enumerated().map { index, start in
            let candidates = candidates[start..<min(start + Constants.checkboxGroupSize, candidates.count)]
            let options = candidates.map { candidate in
                Interaction.ActionRow.CheckboxGroup.Option(
                    value: candidate.id.uuidString,
                    label: displayDate(candidate.date, localization: localization),
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
                label: localization.string(index == 0 ? "date_poll.availability.dates.label" : "date_poll.additional_dates.label", table: "DatePoll"),
                description: localization.string("date_poll.availability.dates.description", table: "DatePoll"),
                component: .checkboxGroup(group)
            ))
        }
        components.append(.label(.init(
            label: localization.string("date_poll.availability.none.label", table: "DatePoll"),
            component: .checkbox(.init(
                custom_id: unavailableCheckboxID(pollID: poll.id),
                default: poll.votes[voterID] != nil && selectedCandidateIDs.isEmpty
            ))
        )))
        return .modal(.init(
            custom_id: componentID(action: .vote, pollID: poll.id),
            title: localization.string("date_poll.availability.title", table: "DatePoll"),
            componentsV2: components
        ))
    }

    static func candidateIDs(from modal: Interaction.ModalSubmit, poll: DatePoll) throws -> Set<UUID> {
        guard let components = modal.componentsV2 else { throw DatePollError.invalidCandidates }
        let expectedGroupIDs = Set(stride(from: 0, to: poll.candidates.count, by: Constants.checkboxGroupSize).enumerated().map {
            checkboxGroupID(pollID: poll.id, index: $0.offset)
        })
        var receivedGroupIDs: Set<String> = []
        var candidateIDs: Set<UUID> = []
        var isUnavailable = false
        var receivedUnavailable = false

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
                guard checkbox.custom_id == unavailableCheckboxID(pollID: poll.id), !receivedUnavailable else {
                    throw DatePollError.invalidCandidates
                }
                receivedUnavailable = true
                isUnavailable = checkbox.value ?? false
            default:
                throw DatePollError.invalidCandidates
            }
        }

        guard receivedGroupIDs == expectedGroupIDs,
              receivedUnavailable,
              isUnavailable == candidateIDs.isEmpty else {
            throw DatePollError.invalidCandidates
        }
        return candidateIDs
    }

    static func finalizationModal(for poll: DatePoll, localization: LocalizationContext) -> Payloads.InteractionResponse {
        let candidates = orderedCandidates(for: poll)
        let bestCandidateIDs = Set(poll.bestCandidates.map(\.id))
        let components = stride(from: 0, to: candidates.count, by: Constants.checkboxGroupSize).enumerated().map { index, start in
            let candidates = candidates[start..<min(start + Constants.checkboxGroupSize, candidates.count)]
            let options = candidates.map { candidate in
                Interaction.ActionRow.CheckboxGroup.Option(
                    value: candidate.id.uuidString,
                    label: localization.string(
                        "date_poll.finalization.option",
                        table: "DatePoll",
                        bestCandidateIDs.contains(candidate.id) ? "⭐ " : "",
                        displayDate(candidate.date, localization: localization),
                        availabilityIcon(for: candidate, poll: poll),
                        String(poll.availableVoters(for: candidate).count),
                        String(poll.votes.count)
                    )
                )
            }
            return Interaction.ModalComponent.label(.init(
                label: localization.string(index == 0 ? "date_poll.finalization.dates.label" : "date_poll.additional_dates.label", table: "DatePoll"),
                description: localization.string("date_poll.finalization.dates.description", table: "DatePoll"),
                component: .checkboxGroup(.init(
                    custom_id: finalizationCheckboxGroupID(pollID: poll.id, index: index),
                    options: options,
                    min_values: 0,
                    max_values: options.count,
                    required: false
                ))
            ))
        }
        return .modal(.init(
            custom_id: componentID(action: .finalize, pollID: poll.id),
            title: localization.string("date_poll.finalization.title", table: "DatePoll"),
            componentsV2: components
        ))
    }

    static func finalizationCandidateIDs(from modal: Interaction.ModalSubmit, poll: DatePoll) throws -> Set<UUID> {
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

        guard receivedGroupIDs == expectedGroupIDs, !candidateIDs.isEmpty else {
            throw DatePollError.invalidFinalizationSelection
        }
        return candidateIDs
    }

    static func votesModal(for poll: DatePoll, localization: LocalizationContext) -> Payloads.InteractionResponse {
        let candidates = orderedCandidates(for: poll)
        let components = stride(from: 0, to: candidates.count, by: 4).map { start in
            let candidateCards = candidates[start..<min(start + 4, candidates.count)].map {
                dateCard(for: $0, poll: poll, localization: localization)
            }
            return Interaction.ModalComponent.textDisplay(.init(content: candidateCards.joined(separator: "\n")))
        }
        return .modal(.init(
            custom_id: componentID(action: .view, pollID: poll.id),
            title: localization.string("date_poll.votes.title", table: "DatePoll"),
            componentsV2: components
        ))
    }

    static func reminderComponents(for poll: DatePoll, localization: LocalizationContext) -> [Interaction.ActionRow] {
        guard poll.deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) else { return [] }
        return [[.button(.init(
            style: .secondary,
            label: localization.string("date_poll.button.remind_tomorrow", table: "DatePoll"),
            custom_id: componentID(action: .delay, pollID: poll.id)
        ))]]
    }

    static func automaticReminderComponents(for poll: DatePoll, localization: LocalizationContext) -> [Interaction.ActionRow] {
        [[.button(.init(
            style: .danger,
            label: localization.string("date_poll.button.stop_automatic_reminders", table: "DatePoll"),
            custom_id: componentID(action: .optOut, pollID: poll.id)
        ))]]
    }

    private static func pollComponents(for poll: DatePoll, foundryFeaturesEnabled: Bool, localization: LocalizationContext) -> [Interaction.MessageLayoutComponent] {
        var components: [Interaction.MessageLayoutComponent] = [
            .textDisplay(.init(content: localization.string(
                "date_poll.message.heading",
                table: "DatePoll",
                DiscordUtils.mention(id: poll.campaignRoleID)
            )))
        ]
        if let description = poll.description, !description.isEmpty {
            components.append(.textDisplay(.init(content: String(description.prefix(1_000)))))
        }
        components.append(.textDisplay(.init(content: participationSummary(for: poll, localization: localization))))

        if poll.status != .cancelled && poll.status != .finalized {
            let leadingCandidates = poll.bestCandidates.sorted(by: { $0.date < $1.date })
            if poll.status != .finalized, let leadingCandidate = leadingCandidates.first {
                components.append(.container(.init(
                    componentsV2: [.textDisplay(.init(content: leadingCandidates.map {
                        leadingDateSummary(for: $0, poll: poll, localization: localization)
                    }.joined(separator: "\n")))],
                    accent_color: leadingAccentColor(for: leadingCandidate, poll: poll)
                )))
            }

            components.append(.separator(.init(divider: true, spacing: .large)))
            let dateCards = orderedCandidates(for: poll).map { candidate in
                Interaction.MessageLayoutComponent.textDisplay(.init(content: dateCard(for: candidate, poll: poll, localization: localization)))
            }
            components.append(.container(.init(componentsV2: dateCards)))
        }

        components.append(contentsOf: controls(for: poll, foundryFeaturesEnabled: foundryFeaturesEnabled, localization: localization).map { .actionRow($0) })
        if let repeatIntervalWeeks = poll.repeatIntervalWeeks {
            let key = repeatIntervalWeeks == 1 ? "date_poll.message.repeats_weekly" : "date_poll.message.repeats_weeks"
            components.append(.textDisplay(.init(content: localization.string(key, table: "DatePoll", String(repeatIntervalWeeks)))))
        }
        let owner = poll.ownerUsername ?? localization.string("date_poll.owner.unknown", table: "DatePoll")
        let footer: String
        if poll.status != .cancelled && poll.status != .finalized {
            footer = localization.string(
                "date_poll.message.footer.open",
                table: "DatePoll",
                owner,
                poll.id,
                DiscordUtils.timestamp(date: poll.deadline, style: .relativeTime)
            )
        } else {
            footer = localization.string("date_poll.message.footer.closed", table: "DatePoll", owner, poll.id)
        }
        components.append(.textDisplay(.init(content: footer)))
        return components
    }

    private static func controls(for poll: DatePoll, foundryFeaturesEnabled: Bool, localization: LocalizationContext) -> [Interaction.ActionRow] {
        var buttons: [Interaction.ActionRow.Component] = []

        if poll.isOpen {
            buttons.append(.button(.init(
                style: .primary,
                label: localization.string("date_poll.button.set_availability", table: "DatePoll"),
                custom_id: componentID(action: .vote, pollID: poll.id)
            )))
        }

        if poll.isOpen, poll.deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) {
            buttons.append(.button(.init(
                style: .secondary,
                label: localization.string("date_poll.button.remind_me", table: "DatePoll"),
                custom_id: componentID(action: .remind, pollID: poll.id)
            )))
        }

        if (poll.status == .open || poll.status == .awaitingFinalization), !poll.votes.isEmpty {
            buttons.append(.button(.init(
                style: .success,
                label: localization.string("date_poll.button.finalize", table: "DatePoll"),
                custom_id: componentID(action: .finalize, pollID: poll.id)
            )))
        }

        if poll.status == .open || poll.status == .awaitingFinalization {
            buttons.append(.button(.init(
                style: .secondary,
                label: localization.string("date_poll.button.edit", table: "DatePoll"),
                custom_id: componentID(action: .edit, pollID: poll.id)
            )))
            buttons.append(.button(.init(
                style: .danger,
                label: localization.string("date_poll.button.cancel", table: "DatePoll"),
                custom_id: componentID(action: .cancel, pollID: poll.id)
            )))
        }

        if poll.status == .finalized {
            buttons.append(.button(.init(
                style: .secondary,
                label: localization.string("date_poll.button.view_votes", table: "DatePoll"),
                custom_id: componentID(action: .view, pollID: poll.id)
            )))
            let finalizedCandidates = poll.finalizedCandidates.sorted { $0.date < $1.date }
            let bookedCandidateIDs = poll.bookedFinalizedCandidateIDs ?? []
            for candidate in finalizedCandidates where !bookedCandidateIDs.contains(candidate.id) {
                buttons.append(.button(.init(
                    style: .primary,
                    label: finalizedCandidates.count == 1
                        ? localization.string("date_poll.button.book", table: "DatePoll")
                        : bookingButtonLabel(for: candidate.date, localization: localization),
                    custom_id: componentID(action: .book, pollID: poll.id, candidateID: candidate.id)
                )))
            }
        }

        if poll.repeatIntervalWeeks != nil {
            buttons.append(.button(.init(
                style: .danger,
                label: localization.string("date_poll.button.cancel_repeat", table: "DatePoll"),
                custom_id: componentID(action: .cancelRepeat, pollID: poll.id)
            )))
        }

        if buttons.isEmpty {
            return [[.button(.init(
                style: .secondary,
                label: localization.string("date_poll.button.poll_closed", table: "DatePoll"),
                custom_id: componentID(action: .vote, pollID: poll.id),
                disabled: true
            ))]]
        }
        return stride(from: 0, to: buttons.count, by: 5).map {
            .init(components: Array(buttons[$0..<min($0 + 5, buttons.count)]))
        }
    }

    private static func participationSummary(for poll: DatePoll, localization: LocalizationContext) -> String {
        switch poll.status {
        case .open:
            var summary = localization.string(
                "date_poll.summary.open",
                table: "DatePoll",
                String(poll.votes.count),
                String(poll.requiredVoterIDs.count)
            )
            if !poll.votes.isEmpty {
                summary += "\n" + localization.string(
                    "date_poll.summary.voted",
                    table: "DatePoll",
                    mentions(for: Array(poll.votes.keys), localization: localization)
                )
            }
            if !poll.outstandingVoterIDs.isEmpty {
                summary += "\n" + localization.string(
                    "date_poll.summary.waiting",
                    table: "DatePoll",
                    mentions(for: poll.outstandingVoterIDs, localization: localization)
                )
            }
            if !poll.noAvailabilityVoterIDs.isEmpty {
                summary += "\n" + localization.string(
                    "date_poll.summary.no_dates",
                    table: "DatePoll",
                    mentions(for: poll.noAvailabilityVoterIDs, localization: localization)
                )
            }
            return summary
        case .awaitingFinalization:
            return localization.string("date_poll.summary.awaiting_finalization", table: "DatePoll")
        case .finalized:
            let candidates = poll.finalizedCandidates.sorted { $0.date < $1.date }
            guard !candidates.isEmpty else {
                return localization.string("date_poll.summary.finalized_empty", table: "DatePoll")
            }
            let dates = candidates.map { "- **\(displayDate($0.date, localization: localization))**" }.joined(separator: "\n")
            return localization.string("date_poll.summary.finalized", table: "DatePoll", dates)
        case .cancelled:
            return localization.string("date_poll.summary.cancelled", table: "DatePoll")
        }
    }

    private static func dateCard(for candidate: DatePollCandidate, poll: DatePoll, localization: LocalizationContext) -> String {
        var card = "### \(displayDate(candidate.date, localization: localization))"
        let voters = poll.votes.count
        let attendees = poll.availableVoters(for: candidate)

        if voters == 0 {
            return card + "\n" + localization.string("date_poll.candidate.no_votes", table: "DatePoll")
        }
        if attendees.isEmpty {
            return card + "\n" + localization.string("date_poll.candidate.no_attendees", table: "DatePoll")
        }
        if attendees.count == voters {
            return card + "\n" + localization.string("date_poll.candidate.everyone_attends", table: "DatePoll")
        }
        return card + "\n" + localization.string(
            "date_poll.candidate.attendees",
            table: "DatePoll",
            mentions(for: attendees, localization: localization)
        )
    }

    private static func leadingDateSummary(for candidate: DatePollCandidate, poll: DatePoll, localization: LocalizationContext) -> String {
        let attendees = poll.availableVoters(for: candidate).count
        return localization.string(
            "date_poll.candidate.leading",
            table: "DatePoll",
            displayDate(candidate.date, localization: localization),
            availabilityIcon(for: candidate, poll: poll),
            String(attendees),
            String(poll.votes.count)
        )
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

    static func displayDate(_ date: Date, localization: LocalizationContext) -> String {
        date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
                .month(.abbreviated)
                .year()
                .locale(localization.locale)
        )
    }

    private static func mentions(for users: [UserSnowflake], localization: LocalizationContext) -> String {
        let displayedUsers = users.prefix(Constants.maximumDisplayedMentions)
        var result = displayedUsers.map(DiscordUtils.mention(id:)).joined(separator: ", ")
        let remaining = users.count - displayedUsers.count
        if remaining > 0 {
            result = localization.string("date_poll.mentions.remaining", table: "DatePoll", result, String(remaining))
        }
        return result
    }

    private static func componentID(action: DatePollAction, pollID: String, candidateID: UUID? = nil) -> String {
        let componentID = "\(Constants.componentPrefix):\(action.rawValue):\(pollID)"
        return candidateID.map { "\(componentID):\($0.uuidString)" } ?? componentID
    }

    private static func bookingButtonLabel(for date: Date, localization: LocalizationContext) -> String {
        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return localization.string("date_poll.button.book_date", table: "DatePoll", formatter.string(from: date))
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
