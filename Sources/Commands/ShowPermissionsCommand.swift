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
    let description = "Shows all assigned permission levels"
    let permissionsLevel: BotPermissionLevel = .admin
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        let perms = Permissions.shared
        let admins = (
            perms.adminUsers.map(DiscordUtils.mention(id:)) +
            perms.adminRoles.map(DiscordUtils.mention(id:))
        )
        let dms = (
            perms.dungeonMasterUsers.map(DiscordUtils.mention(id:)) +
            perms.dungeonMasterRoles.map(DiscordUtils.mention(id:))
        )
        
        func formatMentions(_ mentions: [String]) -> String {
            guard !mentions.isEmpty else {
                return "*None*"
            }
            return mentions.map { "* \($0)" }.joined(separator: "\n")
        }
        
        try await client.respond(
            token: interaction.token,
            message: """
            ## Admin Permissions
            \(formatMentions(admins))
            
            ## Dungeon Master Permissions
            \(formatMentions(dms))
            """
        )
    }
}
