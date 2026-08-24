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
        guard let action = DatePollRenderer.interactionAction(from: modal.custom_id) else {
            throw DatePollError.notFound(modal.custom_id)
        }
        if action.action == .view {
            try await handleVotesModalSubmission(pollID: action.pollID, interaction: interaction)
            return
        }

        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource(isEphemeral: true)
        ).guardSuccess()

        do {
            guard let guildID = interaction.guild_id else { throw DiscordCommandError.noGuild }
            let context = try await guildRegistry.context(for: guildID)
            switch action.action {
            case .create:
                try await handleCreation(modal: modal, interaction: interaction, context: context)
            case .vote:
                try await handleVote(pollID: action.pollID, modal: modal, interaction: interaction, datePolls: context.datePolls, foundryFeaturesEnabled: context.config.foundryFeaturesEnabled)
            case .finalize:
                try await handleFinalization(pollID: action.pollID, modal: modal, interaction: interaction, datePolls: context.datePolls, foundryFeaturesEnabled: context.config.foundryFeaturesEnabled)
            case .edit:
                try await handleEdit(pollID: action.pollID, modal: modal, interaction: interaction, datePolls: context.datePolls, foundryFeaturesEnabled: context.config.foundryFeaturesEnabled)
            default:
                throw DatePollError.notFound(modal.custom_id)
            }
        } catch {
            logger.warning("Failed to handle date poll modal: \(error)")
            try await client.respond(token: interaction.token, message: error.localizedDescription)
        }
    }

    private func handleVotesModalSubmission(pollID: String, interaction: Interaction) async throws {
        guard let guildID = interaction.guild_id else { throw DiscordCommandError.noGuild }
        let context = try await guildRegistry.context(for: guildID)
        let poll = try await context.datePolls.pollForVotesModal(
            pollID: pollID,
            guildID: guildID,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        guard let messageID = poll.messageID else { throw DatePollError.missingMessageReference }

        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredUpdateMessage()
        ).guardSuccess()
        try await client.updateMessage(
            channelId: poll.channelID,
            messageId: messageID,
            payload: DatePollRenderer.messagePayload(for: poll, foundryFeaturesEnabled: context.config.foundryFeaturesEnabled)
        ).guardSuccess()
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

        try await DatePollPublisher.publish(
            poll: poll,
            datePolls: context.datePolls,
            foundryFeaturesEnabled: context.config.foundryFeaturesEnabled,
            client: client
        )

        try await client.respond(token: interaction.token, message: "Date poll created.")
    }

    private func handleVote(pollID: String, modal: Interaction.ModalSubmit, interaction: Interaction, datePolls: DatePollsService, foundryFeaturesEnabled: Bool) async throws {
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
        try await updatePollMessage(for: updatedPoll, datePolls: datePolls, foundryFeaturesEnabled: foundryFeaturesEnabled)
        await removeResponse(token: interaction.token, action: "vote")
    }

    private func handleFinalization(pollID: String, modal: Interaction.ModalSubmit, interaction: Interaction, datePolls: DatePollsService, foundryFeaturesEnabled: Bool) async throws {
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
        let candidateIDs = try DatePollRenderer.finalizationCandidateIDs(from: modal, poll: poll)
        let updatedPoll = try await datePolls.finalizePoll(
            id: pollID,
            candidateIDs: candidateIDs,
            userID: userID,
            roles: member.roles
        )
        try await updatePollMessage(for: updatedPoll, datePolls: datePolls, foundryFeaturesEnabled: foundryFeaturesEnabled)
        await removeResponse(token: interaction.token, action: "finalization")
    }

    private func handleEdit(pollID: String, modal: Interaction.ModalSubmit, interaction: Interaction, datePolls: DatePollsService, foundryFeaturesEnabled: Bool) async throws {
        guard let member = interaction.member, let userID = member.user?.id, let guildID = interaction.guild_id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePolls.pollForManagementControl(
            pollID: pollID,
            userID: userID,
            roles: member.roles,
            guildID: guildID,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        let form = try DatePollCreationForm(from: modal)
        let voterIDs = try await DatePollMemberResolver.voterIDs(
            for: form.campaignRoleID,
            guildID: guildID,
            client: client
        )
        guard !voterIDs.isEmpty else { throw DatePollError.invalidCandidates }
        let polls = try await datePolls.editPoll(
            id: pollID,
            campaignRoleID: form.campaignRoleID,
            requiredVoterIDs: voterIDs,
            candidateDates: form.candidateDates,
            description: form.description,
            deadline: form.deadline,
            repeatIntervalWeeks: form.repeatIntervalWeeks,
            userID: userID,
            roles: member.roles
        )
        for poll in polls {
            do {
                try await updatePollMessage(for: poll, datePolls: datePolls, foundryFeaturesEnabled: foundryFeaturesEnabled)
            } catch {
                logger.warning("Failed to update edited date poll \(poll.id): \(error)")
            }
        }
        await removeResponse(token: interaction.token, action: "edit")
    }

    private func updatePollMessage(for poll: DatePoll, datePolls: DatePollsService, foundryFeaturesEnabled: Bool) async throws {
        guard let messageID = poll.messageID else { throw DatePollError.missingMessageReference }
        try await client.updateMessage(
            channelId: poll.channelID,
            messageId: messageID,
            payload: DatePollRenderer.messagePayload(for: poll, foundryFeaturesEnabled: foundryFeaturesEnabled)
        ).guardSuccess()
        await datePolls.markMessageSynced(pollID: poll.id, eventID: poll.messageSyncEventID)
    }

    private func removeResponse(token: String, action: String) async {
        do {
            try await client.deleteOriginalInteractionResponse(token: token).guardSuccess()
        } catch {
            logger.warning("Failed to remove date poll \(action) response: \(error)")
        }
    }
}
