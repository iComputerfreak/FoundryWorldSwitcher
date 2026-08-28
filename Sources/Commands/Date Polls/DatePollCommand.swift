//
//  DatePollCommand.swift
//

import DiscordBM
import Logging

struct DatePollCommand: DiscordCommand {
    let logger = Logger(label: String(describing: Self.self))
    let name = "datepoll"
    let description = "Opens a campaign date-poll form with dates, deadline, and optional repeat"
    let permissionsLevel: BotPermissionLevel = .dungeonMaster
    let requiresImmediateResponse = true

    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: any DiscordClient
    ) async throws {
        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: DatePollRenderer.creationModal(localization: context.config.localization)
        ).guardSuccess()
    }
}
