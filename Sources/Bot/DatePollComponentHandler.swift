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
        if action.action == "finalize" {
            try await showFinalizationModal(pollID: action.pollID, interaction: interaction)
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
            case "cancel":
                try await handleCancellation(pollID: action.pollID, interaction: interaction)
            default:
                throw DatePollError.notFound(component.custom_id)
            }
        } catch {
            logger.warning("Failed to handle date poll interaction: \(error)")
            try await client.respond(token: interaction.token, message: error.localizedDescription)
        }
    }

    private func showAvailabilityModal(pollID: String, interaction: Interaction) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        do {
            let poll = try await datePollsService.pollForVoteModal(
                pollID: pollID,
                roles: member.roles,
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

    private func showFinalizationModal(pollID: String, interaction: Interaction) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        do {
            let poll = try await datePollsService.pollForManagementControl(
                pollID: pollID,
                userID: userID,
                roles: member.roles,
                guildID: interaction.guild_id,
                channelID: interaction.channel_id,
                messageID: interaction.message?.id
            )
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: DatePollRenderer.finalizationModal(for: poll)
            ).guardSuccess()
        } catch {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(content: error.localizedDescription, flags: [.ephemeral]))
            ).guardSuccess()
        }
    }

    private func handleCancellation(pollID: String, interaction: Interaction) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePollsService.pollForManagementControl(
            pollID: pollID,
            userID: userID,
            roles: member.roles,
            guildID: interaction.guild_id,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        let poll = try await datePollsService.cancelPoll(id: pollID, userID: userID, roles: member.roles)
        guard let messageID = poll.messageID else { throw DatePollError.missingMessageReference }
        try await client.updateMessage(
            channelId: poll.channelID,
            messageId: messageID,
            payload: DatePollRenderer.messagePayload(for: poll)
        ).guardSuccess()
        do {
            try await client.deleteOriginalInteractionResponse(token: interaction.token).guardSuccess()
        } catch {
            logger.warning("Failed to remove date poll cancellation response: \(error)")
        }
    }
}
