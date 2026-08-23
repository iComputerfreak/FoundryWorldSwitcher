//
//  DatePollModalHandler.swift
//

import DiscordBM
import Logging

struct DatePollModalHandler {
    let client: any DiscordClient
    private let logger = Logger(label: String(describing: Self.self))

    func handle(_ modal: Interaction.ModalSubmit, interaction: Interaction) async throws {
        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource(isEphemeral: true)
        ).guardSuccess()

        do {
            guard let action = DatePollRenderer.interactionAction(from: modal.custom_id), action.action == "vote" else {
                throw DatePollError.notFound(modal.custom_id)
            }
            guard let member = interaction.member, let userID = member.user?.id, let guildID = interaction.guild_id else {
                throw DiscordCommandError.noUser
            }
            let poll = try await datePollsService.pollForVoteModal(
                pollID: action.pollID,
                roles: member.roles,
                guildID: guildID,
                channelID: interaction.channel_id,
                messageID: interaction.message?.id
            )
            let currentVoterIDs = try await DatePollMemberResolver.voterIDs(
                for: poll.campaignRoleID,
                guildID: guildID,
                client: client
            )
            let candidateIDs = try DatePollRenderer.candidateIDs(from: modal, poll: poll)
            let updatedPoll = try await datePollsService.vote(
                pollID: action.pollID,
                voterID: userID,
                candidateIDs: candidateIDs,
                currentVoterIDs: currentVoterIDs,
                guildID: guildID,
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
        } catch {
            logger.warning("Failed to handle date poll modal: \(error)")
            try await client.respond(token: interaction.token, message: error.localizedDescription)
        }
    }
}
