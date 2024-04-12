//
//  DiscordCommandError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM
import Foundation

enum DiscordCommandError: Error, LocalizedError {
    case unknownCommand(commandName: String)
    case missingArgument(argumentName: String)
    case noMember
    case noUser
    case noGuild
    case worldDoesNotExist(worldID: String)
    case unauthorized(requiredLevel: BotPermissionLevel)
    
    var errorDescription: String? {
        switch self {
        case .unknownCommand(let commandName):
            return "Unknown command `\(commandName)`."
        case .missingArgument(let argumentName):
            return "Missing argument `\(argumentName)`."
        case .noMember:
            return "There is no server member associated with the command."
        case .noUser:
            return "There is no user associated with the command."
        case .noGuild:
            return "There is no guild/server associated with the command."
        case .worldDoesNotExist(worldID: let worldID):
            return "The world `\(worldID)` does not exist."
        case .unauthorized(let requiredLevel):
            return "You need at least permission level `\(requiredLevel)` to execute this command."
        }
    }
}
