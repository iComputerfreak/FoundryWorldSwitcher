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
        
        let userPermissions = Permissions.shared.permissionsLevel(of: userID, roles: roles)
        try await client.respond(
            token: interaction.token,
            message: "Your current permission level is `\(userPermissions)`"
        )
    }
}
