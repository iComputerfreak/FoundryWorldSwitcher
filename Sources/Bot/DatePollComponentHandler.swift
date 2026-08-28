//
//  DatePollComponentHandler.swift
//

import DiscordBM
import Foundation
import Logging

struct DatePollComponentHandler {
    let client: any DiscordClient
    let guildRegistry: GuildRegistry
    private let logger = Logger(label: String(describing: Self.self))

    func handle(_ component: Interaction.MessageComponent, interaction: Interaction) async throws {
        guard let action = DatePollRenderer.interactionAction(from: component.custom_id) else {
            return
        }
        let context: GuildContext
        if let guildID = interaction.guild_id {
            context = try await guildRegistry.context(for: guildID)
        } else {
            guard action.action == .delay || action.action == .optOut else { throw DiscordCommandError.noGuild }
            context = try await guildRegistry.context(forDatePollID: action.pollID)
        }
        if action.action == .vote {
            try await showAvailabilityModal(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls, localization: context.config.localization)
            return
        }
        if action.action == .finalize {
            try await showFinalizationModal(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls, localization: context.config.localization)
            return
        }
        if action.action == .edit {
            try await showEditModal(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls, localization: context.config.localization)
            return
        }
        if action.action == .view {
            try await showVotesModal(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls, localization: context.config.localization)
            return
        }
        if action.action == .book, let candidateID = action.candidateID {
            try await showBookingModal(
                pollID: action.pollID,
                candidateID: candidateID,
                interaction: interaction,
                context: context
            )
            return
        }

        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource(isEphemeral: true)
        ).guardSuccess()

        do {
            switch action.action {
            case .remind:
                try await handleReminder(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls, localization: context.config.localization)
            case .delay:
                try await handleReminderDelay(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls, localization: context.config.localization)
            case .optOut:
                try await handleAutomaticReminderOptOut(interaction: interaction, preferences: context.datePollReminderPreferences, localization: context.config.localization)
            case .cancel:
                try await handleCancellation(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls)
            case .cancelRepeat:
                try await handleRepeatCancellation(pollID: action.pollID, interaction: interaction, datePolls: context.datePolls)
            default:
                throw DatePollError.notFound(component.custom_id)
            }
        } catch {
            logger.warning("Failed to handle date poll interaction: \(error)")
            try await client.respond(
                token: interaction.token,
                message: UserFacingErrorRenderer.message(for: error, localization: context.config.localization)
            )
        }
    }

    private func showAvailabilityModal(pollID: String, interaction: Interaction, datePolls: DatePollsService, localization: LocalizationContext) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        do {
            let poll = try await datePolls.pollForVoteModal(
                pollID: pollID,
                roles: member.roles,
                guildID: interaction.guild_id,
                channelID: interaction.channel_id,
                messageID: interaction.message?.id
            )
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: DatePollRenderer.availabilityModal(for: poll, voterID: userID, localization: localization)
            ).guardSuccess()
        } catch {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(
                    content: UserFacingErrorRenderer.message(for: error, localization: localization),
                    flags: [.ephemeral]
                ))
            ).guardSuccess()
        }
    }

    private func handleReminder(pollID: String, interaction: Interaction, datePolls: DatePollsService, localization: LocalizationContext) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePolls.pollForVoteModal(
            pollID: pollID,
            roles: member.roles,
            guildID: interaction.guild_id,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        _ = try await datePolls.requestReminder(pollID: pollID, voterID: userID)
        try await client.respond(token: interaction.token, message: localization.string("date_poll.reminder.scheduled", table: "DatePoll"))
    }

    private func handleReminderDelay(pollID: String, interaction: Interaction, datePolls: DatePollsService, localization: LocalizationContext) async throws {
        guard let userID = interaction.user?.id ?? interaction.member?.user?.id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePolls.delayReminder(pollID: pollID, userID: userID)
        try await client.respond(token: interaction.token, message: localization.string("date_poll.reminder.delayed", table: "DatePoll"))
    }

    private func handleAutomaticReminderOptOut(
        interaction: Interaction,
        preferences: DatePollReminderPreferences,
        localization: LocalizationContext
    ) async throws {
        guard let userID = interaction.user?.id ?? interaction.member?.user?.id else {
            throw DiscordCommandError.noUser
        }
        await preferences.optOut(userID)
        try await client.respond(token: interaction.token, message: localization.string("date_poll.reminder.disabled", table: "DatePoll"))
    }

    private func showFinalizationModal(pollID: String, interaction: Interaction, datePolls: DatePollsService, localization: LocalizationContext) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        do {
            let poll = try await datePolls.pollForManagementControl(
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
                payload: DatePollRenderer.finalizationModal(for: poll, localization: localization)
            ).guardSuccess()
        } catch {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(content: UserFacingErrorRenderer.message(for: error, localization: localization), flags: [.ephemeral]))
            ).guardSuccess()
        }
    }

    private func showEditModal(pollID: String, interaction: Interaction, datePolls: DatePollsService, localization: LocalizationContext) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        do {
            let poll = try await datePolls.pollForManagementControl(
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
                payload: DatePollRenderer.editModal(for: poll, localization: localization)
            ).guardSuccess()
        } catch {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(content: UserFacingErrorRenderer.message(for: error, localization: localization), flags: [.ephemeral]))
            ).guardSuccess()
        }
    }

    private func showVotesModal(pollID: String, interaction: Interaction, datePolls: DatePollsService, localization: LocalizationContext) async throws {
        do {
            let poll = try await datePolls.pollForVotesModal(
                pollID: pollID,
                guildID: interaction.guild_id,
                channelID: interaction.channel_id,
                messageID: interaction.message?.id
            )
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: DatePollRenderer.votesModal(for: poll, localization: localization)
            ).guardSuccess()
        } catch {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(content: UserFacingErrorRenderer.message(for: error, localization: localization), flags: [.ephemeral]))
            ).guardSuccess()
        }
    }

    private func showBookingModal(
        pollID: String,
        candidateID: UUID,
        interaction: Interaction,
        context: GuildContext
    ) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        do {
            guard context.permissions.permissionsLevel(of: userID, roles: member.roles) >= .dungeonMaster else {
                throw DiscordCommandError.unauthorized(requiredLevel: .dungeonMaster)
            }
            let result = try await context.datePolls.finalizedCandidateForBookingControl(
                pollID: pollID,
                candidateID: candidateID,
                guildID: interaction.guild_id,
                channelID: interaction.channel_id,
                messageID: interaction.message?.id
            )
            let dateTime = Utils.date(on: result.candidate.date, at: context.config.defaultEventBookingTime)
            let worlds = context.config.foundryFeaturesEnabled ? try await PterodactylAPI.shared.worlds() : []
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: BookingRenderer.creationModal(
                    kind: .event,
                    worlds: worlds,
                    defaultEventBookingTime: context.config.defaultEventBookingTime,
                    localization: context.config.localization,
                    dateTime: dateTime,
                    campaignRoleID: result.poll.campaignRoleID,
                    sourcePollID: pollID,
                    sourceCandidateID: candidateID
                )
            ).guardSuccess()
        } catch {
            try await client.createInteractionResponse(
                id: interaction.id,
                token: interaction.token,
                payload: .channelMessageWithSource(.init(content: UserFacingErrorRenderer.message(for: error, localization: context.config.localization), flags: [.ephemeral]))
            ).guardSuccess()
        }
    }

    private func handleCancellation(pollID: String, interaction: Interaction, datePolls: DatePollsService) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePolls.pollForManagementControl(
            pollID: pollID,
            userID: userID,
            roles: member.roles,
            guildID: interaction.guild_id,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        let poll = try await datePolls.cancelPoll(id: pollID, userID: userID, roles: member.roles)
        try await DatePollMessageSynchronizer.synchronizeLatest(
            pollID: poll.id,
            datePolls: datePolls,
            client: client
        )
        do {
            try await client.deleteOriginalInteractionResponse(token: interaction.token).guardSuccess()
        } catch {
            logger.warning("Failed to remove date poll cancellation response: \(error)")
        }
    }

    private func handleRepeatCancellation(pollID: String, interaction: Interaction, datePolls: DatePollsService) async throws {
        guard let member = interaction.member, let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        _ = try await datePolls.pollForRepeatManagementControl(
            pollID: pollID,
            userID: userID,
            roles: member.roles,
            guildID: interaction.guild_id,
            channelID: interaction.channel_id,
            messageID: interaction.message?.id
        )
        let polls = try await datePolls.cancelRepeat(id: pollID, userID: userID, roles: member.roles)
        for poll in polls {
            do {
                try await DatePollMessageSynchronizer.synchronizeLatest(
                    pollID: poll.id,
                    datePolls: datePolls,
                    client: client
                )
            } catch {
                logger.warning("Failed to update date poll after repeat cancellation: \(error)")
            }
        }
        do {
            try await client.deleteOriginalInteractionResponse(token: interaction.token).guardSuccess()
        } catch {
            logger.warning("Failed to remove date poll repeat cancellation response: \(error)")
        }
    }
}
