//
//  SetPermissionLevel.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM
import Logging

struct SetPermissionLevel: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "setpermissionlevel"
    let description = "Sets a permission level for a user or a role."
    let permissionsLevel: BotPermissionLevel = .admin
    
    static let permissionLevelOption = ApplicationCommand.Option(
        type: .integer,
        name: "level",
        description: "The permission level.",
        required: true,
        choices: BotPermissionLevel.allCases.map { level in
            ApplicationCommand.Option.Choice(name: level.description, value: .int(level.rawValue))
        }
    )
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .subCommand,
            name: "user",
            description: "Sets a permission level for a user.",
            options: [
                .init(
                    type: .user,
                    name: "user",
                    description: "The user to give permissions.",
                    required: true
                ),
                permissionLevelOption
            ]
        ),
        .init(
            type: .subCommand,
            name: "role",
            description: "Sets a permission level for a role.",
            options: [
                .init(
                    type: .role,
                    name: "role",
                    description: "The role to give permissions.",
                    required: true
                ),
                permissionLevelOption
            ]
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        // MARK: Parse the permission level
        func parseLevel(of subcommand: Interaction.ApplicationCommand.Option) throws -> BotPermissionLevel {
            guard
                let newLevelValue = try subcommand.option(named: Self.permissionLevelOption.name)?
                    .value?.requireInt(),
                let newLevel = BotPermissionLevel(rawValue: newLevelValue)
            else {
                throw DiscordCommandError.missingArgument(argumentName: "level")
            }
            return newLevel
        }
        
        // MARK: Parse the user/role
        if let userSubcommand = applicationCommand.option(named: "user") {
            guard let userID = try userSubcommand.option(named: "user")?.value?.requireString() else {
                throw DiscordCommandError.missingArgument(argumentName: "user")
            }
            let user = UserSnowflake(userID)
            let newLevel = try parseLevel(of: userSubcommand)
            Permissions.shared.setPermissionLevel(of: user, to: newLevel)
            try await sendSuccessMessage(
                interaction: interaction,
                client: client,
                user: user,
                newPermissionLevel: newLevel
            )
        } else if let roleSubcommand = applicationCommand.option(named: "role") {
            guard let roleID = try roleSubcommand.option(named: "role")?.value?.requireString() else {
                throw DiscordCommandError.missingArgument(argumentName: "role")
            }
            let role = RoleSnowflake(roleID)
            let newLevel = try parseLevel(of: roleSubcommand)
            Permissions.shared.setPermissionLevel(of: RoleSnowflake(roleID), to: newLevel)
            try await sendSuccessMessage(
                interaction: interaction,
                client: client,
                role: role,
                newPermissionLevel: newLevel
            )
        } else {
            throw DiscordCommandError.missingArgument(argumentName: "user/role")
        }
    }
    
    private func sendSuccessMessage(
        interaction: Interaction,
        client: DiscordClient,
        user: UserSnowflake,
        newPermissionLevel: BotPermissionLevel
    ) async throws {
        let mention = try Utils.mention(of: user)
        try await client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: .init(content: "User \(mention) now has permission level `\(newPermissionLevel.description)`.")
        ).guardSuccess()
    }
    
    private func sendSuccessMessage(
        interaction: Interaction,
        client: DiscordClient,
        role: RoleSnowflake,
        newPermissionLevel: BotPermissionLevel
    ) async throws {
        let mention = try Utils.mention(of: role)
        try await client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: .init(content: "Role \(mention) now has `\(newPermissionLevel.description)` permissions.")
        ).guardSuccess()
    }
}
