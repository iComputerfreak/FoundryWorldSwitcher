//
//  DiscordCommandError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM

enum DiscordCommandError: Error {
    case unknownCommand(commandName: String)
    case missingArgument(argumentName: String)
    case noMember
    case noUser
    case noGuild
    case invalidGuildID(guildID: GuildSnowflake)
    case unauthorized(requiredLevel: BotPermissionLevel)
}
