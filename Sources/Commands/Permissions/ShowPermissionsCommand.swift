//
//  ShowPermissionsCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM
import Logging

struct ShowPermissionsCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "showpermissions"
    let description = "Shows stored Admin and Dungeon Master user and role assignments"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
        client: DiscordClient
    ) async throws {
        let perms = context.permissions
        let admins = (
            perms.adminUsers.map(DiscordUtils.mention(id:)) +
            perms.adminRoles.map(DiscordUtils.mention(id:))
        )
        let dms = (
            perms.dungeonMasterUsers.map(DiscordUtils.mention(id:)) +
            perms.dungeonMasterRoles.map(DiscordUtils.mention(id:))
        )
        let localization = context.config.localization
        
        func formatMentions(_ mentions: [String]) -> String {
            guard !mentions.isEmpty else {
                return localization.string("common.none", table: "Commands")
            }
            return mentions.map { "* \($0)" }.joined(separator: "\n")
        }
        
        try await client.respond(
            token: interaction.token,
            message: localization.string(
                "permissions.list",
                table: "Commands",
                formatMentions(admins),
                formatMentions(dms)
            )
        )
    }
}
