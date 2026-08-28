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
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "mypermissions"
    let description = "Returns your permission level"
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        guard
            let member = interaction.member,
            let userID = member.user?.id
        else {
            throw DiscordBotError.noUser
        }
        // Get all roles of the user
        let roles: [RoleSnowflake] = member.roles
        
        let userPermissions = context.permissions.permissionsLevel(of: userID, roles: roles)
        let localization = context.config.localization
        try await client.respond(
            token: interaction.token,
            message: localization.string(
                "permissions.current",
                table: "Commands",
                localizedPermissionLevel(userPermissions, localization: localization)
            )
        )
    }

    private func localizedPermissionLevel(_ level: BotPermissionLevel, localization: LocalizationContext) -> String {
        switch level {
        case .user: localization.string("permission_level.user", table: "Commands")
        case .dungeonMaster: localization.string("permission_level.dungeon_master", table: "Commands")
        case .admin: localization.string("permission_level.admin", table: "Commands")
        }
    }
}
