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
    let description = "Assigns a permission level to a user or role in this server"
    let permissionsLevel: BotPermissionLevel = .admin
    
    static let permissionLevelOption = ApplicationCommand.Option(
        type: .integer,
        name: "level",
        description: "Permission level to assign",
        required: true,
        choices: BotPermissionLevel.allCases.map { level in
            ApplicationCommand.Option.Choice(name: level.description, value: .int(level.rawValue))
        }
    )
    
    let options: [ApplicationCommand.Option]? = [
        .init(
            type: .subCommand,
            name: "user",
            description: "Sets a permission level for a user",
            options: [
                .init(
                    type: .user,
                    name: "user",
                    description: "The user to give permissions",
                    required: true
                ),
                permissionLevelOption
            ]
        ),
        .init(
            type: .subCommand,
            name: "role",
            description: "Sets a permission level for a role",
            options: [
                .init(
                    type: .role,
                    name: "role",
                    description: "The role to give permissions",
                    required: true
                ),
                permissionLevelOption
            ]
        )
    ]
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        context: GuildContext,
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
            context.permissions.setPermissionLevel(of: user, to: newLevel)
            try await sendSuccessMessage(
                interaction: interaction,
                client: client,
                user: user,
                newPermissionLevel: newLevel,
                localization: context.config.localization
            )
        } else if let roleSubcommand = applicationCommand.option(named: "role") {
            guard let roleID = try roleSubcommand.option(named: "role")?.value?.requireString() else {
                throw DiscordCommandError.missingArgument(argumentName: "role")
            }
            let role = RoleSnowflake(roleID)
            let newLevel = try parseLevel(of: roleSubcommand)
            context.permissions.setPermissionLevel(of: RoleSnowflake(roleID), to: newLevel)
            try await sendSuccessMessage(
                interaction: interaction,
                client: client,
                role: role,
                newPermissionLevel: newLevel,
                localization: context.config.localization
            )
        } else {
            throw DiscordCommandError.missingSubcommand
        }
    }
    
    private func sendSuccessMessage(
        interaction: Interaction,
        client: DiscordClient,
        user: UserSnowflake,
        newPermissionLevel: BotPermissionLevel,
        localization: LocalizationContext
    ) async throws {
        let mention = DiscordUtils.mention(id: user)
        try await client.respond(
            token: interaction.token,
            message: localization.string(
                "permissions.user_updated",
                table: "Commands",
                mention,
                localizedPermissionLevel(newPermissionLevel, localization: localization)
            )
        )
    }
    
    private func sendSuccessMessage(
        interaction: Interaction,
        client: DiscordClient,
        role: RoleSnowflake,
        newPermissionLevel: BotPermissionLevel,
        localization: LocalizationContext
    ) async throws {
        let mention = DiscordUtils.mention(id: role)
        try await client.respond(
            token: interaction.token,
            message: localization.string(
                "permissions.role_updated",
                table: "Commands",
                mention,
                localizedPermissionLevel(newPermissionLevel, localization: localization)
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
