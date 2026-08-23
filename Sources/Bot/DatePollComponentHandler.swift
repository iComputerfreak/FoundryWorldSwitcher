//
//  DatePollComponentHandler.swift
//

import DiscordBM
import Logging

struct DatePollComponentHandler {
    let client: any DiscordClient
    private let logger = Logger(label: String(describing: Self.self))

    func handle(_ component: Interaction.MessageComponent, interaction: Interaction) async throws {
        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource(isEphemeral: true)
        ).guardSuccess()

        do {
            guard let action = DatePollRenderer.interactionAction(from: component.custom_id) else {
                throw DatePollError.notFound(component.custom_id)
            }
            switch action.action {
            case "vote":
                try await handleVote(pollID: action.pollID, component: component, interaction: interaction)
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

    private func handleVote(
        pollID: String,
        component: Interaction.MessageComponent,
        interaction: Interaction
    ) async throws {
        guard let userID = interaction.member?.user?.id else {
            throw DiscordCommandError.noUser
        }
        let poll = try await datePollsService.poll(id: pollID)
        let candidateIDs = try DatePollRenderer.candidateIDs(from: component.values ?? [], poll: poll)
        let updatedPoll = try await datePollsService.vote(
            pollID: pollID,
            voterID: userID,
            candidateIDs: candidateIDs,
            guildID: interaction.guild_id,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        guard let messageID = updatedPoll.messageID else { throw DatePollError.missingMessageReference }
        try await client.updateMessage(
            channelId: updatedPoll.channelID,
            messageId: messageID,
            payload: DatePollRenderer.messagePayload(for: updatedPoll)
        ).guardSuccess()
        try await client.respond(token: interaction.token, message: "Vote recorded.")
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
