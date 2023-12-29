//
//  MyPermissionsCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import Foundation
import DiscordBM
import Logging

struct MyPermissionsCommand: DiscordCommand {
    let name = "mypermissions"
    let description = "Returns your permission level."
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        guard let userID = interaction.member?.user?.id else {
            throw DiscordBotError.noUser
        }
        // TODO: Get all roles of the user
        let roles: [RoleSnowflake] = []
        
        let userPermissions = Permissions.shared.permissionsLevel(of: userID, roles: roles)
        try await client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: Payloads.EditWebhookMessage(
                content: "Your current permission level is `\(userPermissions)`"
            )
        ).guardSuccess()
    }
}
