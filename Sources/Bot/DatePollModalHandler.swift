//
//  DatePollModalHandler.swift
//

import DiscordBM
import Logging

struct DatePollModalHandler {
    let client: any DiscordClient
    let guildRegistry: GuildRegistry
    private let logger = Logger(label: String(describing: Self.self))

    func handle(_ modal: Interaction.ModalSubmit, interaction: Interaction) async throws {
        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource(isEphemeral: true)
        ).guardSuccess()

        do {
            guard let guildID = interaction.guild_id else { throw DiscordCommandError.noGuild }
            let context = await guildRegistry.context(for: guildID)
            guard let action = DatePollRenderer.interactionAction(from: modal.custom_id) else {
                throw DatePollError.notFound(modal.custom_id)
            }
            switch action.action {
            case "create":
                try await handleCreation(modal: modal, interaction: interaction, context: context)
            case "vote":
                try await handleVote(pollID: action.pollID, modal: modal, interaction: interaction, datePolls: context.datePolls)
            case "finalize":
                try await handleFinalization(pollID: action.pollID, modal: modal, interaction: interaction, datePolls: context.datePolls)
            default:
                throw DatePollError.notFound(modal.custom_id)
            }
        } catch {
            logger.warning("Failed to handle date poll modal: \(error)")
            try await client.respond(token: interaction.token, message: error.localizedDescription)
        }
    }

    private func handleCreation(
        modal: Interaction.ModalSubmit,
        interaction: Interaction,
        context: GuildContext
    ) async throws {
        guard
            let member = interaction.member,
            let owner = member.user,
            let guildID = interaction.guild_id,
            let channelID = interaction.channel_id
        else {
            throw DiscordCommandError.noGuild
        }
        guard context.permissions.permissionsLevel(of: owner.id, roles: member.roles) >= .dungeonMaster else {
            throw DiscordCommandError.unauthorized(requiredLevel: .dungeonMaster)
        }

        let form = try DatePollCreationForm(from: modal)
        let voters = try await DatePollMemberResolver.voterIDs(for: form.campaignRoleID, guildID: guildID, client: client)
        guard !voters.isEmpty else { throw DatePollError.invalidCandidates }

        let poll = await context.datePolls.createPoll(
            ownerID: owner.id,
            ownerUsername: owner.username,
            guildID: guildID,
            channelID: channelID,
            campaignRoleID: form.campaignRoleID,
            requiredVoterIDs: voters,
            deadline: form.deadline,
            description: form.description,
            candidateDates: form.candidateDates,
            repeatIntervalWeeks: form.repeatIntervalWeeks
        )

        do {
            let message = try await client.createMessage(
                channelId: channelID,
                payload: DatePollRenderer.createMessagePayload(for: poll)
            ).decode()
            do {
                try await context.datePolls.publishPoll(id: poll.id, messageID: message.id)
            } catch {
                try? await client.deleteMessage(channelId: channelID, messageId: message.id).guardSuccess()
                throw error
            }
        } catch {
            await context.datePolls.discardUnpublishedPoll(id: poll.id)
            throw error
        }

        try await client.respond(token: interaction.token, message: "Date poll created.")
    }

    private func handleVote(pollID: String, modal: Interaction.ModalSubmit, interaction: Interaction, datePolls: DatePollsService) async throws {
        guard let member = interaction.member, let userID = member.user?.id, let guildID = interaction.guild_id else {
            throw DiscordCommandError.noUser
        }
        let poll = try await datePolls.pollForVoteModal(
            pollID: pollID,
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
        let updatedPoll = try await datePolls.vote(
            pollID: pollID,
            voterID: userID,
            candidateIDs: candidateIDs,
            currentVoterIDs: currentVoterIDs,
            guildID: guildID,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        try await updatePollMessage(for: updatedPoll)
        await removeResponse(token: interaction.token, action: "vote")
    }

    private func handleFinalization(pollID: String, modal: Interaction.ModalSubmit, interaction: Interaction, datePolls: DatePollsService) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        let poll = try await datePolls.pollForManagementControl(
            pollID: pollID,
            userID: userID,
            roles: member.roles,
            guildID: interaction.guild_id,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        let candidateID = try DatePollRenderer.finalizationCandidateID(from: modal, poll: poll)
        guard let candidate = poll.candidate(id: candidateID) else {
            throw DatePollError.invalidFinalizationSelection
        }
        let updatedPoll = try await datePolls.finalizePoll(
            id: pollID,
            date: candidate.date,
            userID: userID,
            roles: member.roles
        )
        try await updatePollMessage(for: updatedPoll)
        await removeResponse(token: interaction.token, action: "finalization")
    }

    private func updatePollMessage(for poll: DatePoll) async throws {
        guard let messageID = poll.messageID else { throw DatePollError.missingMessageReference }
        try await client.updateMessage(
            channelId: poll.channelID,
            messageId: messageID,
            payload: DatePollRenderer.messagePayload(for: poll)
        ).guardSuccess()
    }

    private func removeResponse(token: String, action: String) async {
        do {
            try await client.deleteOriginalInteractionResponse(token: token).guardSuccess()
        } catch {
            logger.warning("Failed to remove date poll \(action) response: \(error)")
        }
    }
}
