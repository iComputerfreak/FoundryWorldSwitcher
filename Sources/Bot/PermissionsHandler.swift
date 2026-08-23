//
//  PermissionsHandler.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM

struct PermissionsHandler {
    let cache: DiscordCache
    
    func checkAuthorization(of member: Guild.Member, for command: any DiscordCommand, in context: GuildContext) throws {
        guard let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        let permissionLevel = context.permissions.permissionsLevel(of: UserSnowflake(userID), roles: member.roles)
        guard permissionLevel >= command.permissionsLevel else {
            throw DiscordCommandError.unauthorized(requiredLevel: command.permissionsLevel)
        }
        guard !command.requiresFoundryFeatures || context.config.foundryFeaturesEnabled else {
            throw DiscordCommandError.foundryFeaturesDisabled
        }
    }
}
