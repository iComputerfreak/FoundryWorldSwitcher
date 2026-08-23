//
//  DatePollComponentHandler.swift
//

import DiscordBM
import Logging

struct DatePollComponentHandler {
    let client: any DiscordClient
    private let logger = Logger(label: String(describing: Self.self))

    func handle(_ component: Interaction.MessageComponent, interaction: Interaction) async throws {
        guard let action = DatePollRenderer.interactionAction(from: component.custom_id) else {
            return
        }
        if action.action == "vote" {
            try await showAvailabilityModal(pollID: action.pollID, interaction: interaction)
            return
        }

        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource(isEphemeral: true)
        ).guardSuccess()

        do {
            switch action.action {
            case "remind":
                try await handleReminder(pollID: action.pollID, interaction: interaction)
            case "delay":
                try await handleReminderDelay(pollID: action.pollID, interaction: interaction)
            default:
                throw DatePollError.notFound(component.custom_id)
            }
        } catch {
            logger.warning("Failed to handle date poll interaction: \(error)")
            try await client.respond(token: interaction.token, message: error.localizedDescription)
        }
    }

    private func showAvailabilityModal(pollID: String, interaction: Interaction) async throws {
        guard let userID = interaction.member?.user?.id else {
            throw DiscordCommandError.noUser
        }
        do {
            let poll = try await datePollsService.pollForVoteModal(
                pollID: pollID,
                voterID: userID,
                guildID: interaction.guild_id,
                channelID: interaction.channel_id,
                messageID: interaction.message?.id
            )
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: DatePollRenderer.availabilityModal(for: poll, voterID: userID)
            ).guardSuccess()
        } catch {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(content: error.localizedDescription, flags: [.ephemeral]))
            ).guardSuccess()
        }
    }

    private func handleReminder(pollID: String, interaction: Interaction) async throws {
        guard let userID = interaction.member?.user?.id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePollsService.requestReminder(pollID: pollID, voterID: userID)
        try await client.respond(token: interaction.token, message: "I will remind you in 24 hours.")
    }

    private func handleReminderDelay(pollID: String, interaction: Interaction) async throws {
        guard let userID = interaction.user?.id ?? interaction.member?.user?.id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePollsService.delayReminder(pollID: pollID, userID: userID)
        try await client.respond(token: interaction.token, message: "I will remind you once more in 24 hours.")
    }
}
