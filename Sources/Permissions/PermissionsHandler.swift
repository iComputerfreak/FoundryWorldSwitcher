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
    
    func checkAuthorization(of member: Guild.Member, for command: any DiscordCommand) throws {
        guard let userID = member.user?.id else {
            throw DiscordCommandError.noUser
        }
        let userPermission = Permissions.shared.userPermissionLevel(of: UserSnowflake(userID))
        // If the user itself has sufficient permissions, we can exit successfully here
        if userPermission >= command.permissionsLevel {
            return
        }
        // Otherwise, we need to check the user's roles
        for role in member.roles {
            if Permissions.shared.rolePermissionLevel(of: role) >= command.permissionsLevel {
                return
            }
        }
        // If we did not find a role with sufficient permissions until here, we throw an error
        throw DiscordCommandError.unauthorized(requiredLevel: command.permissionsLevel)
    }
}
