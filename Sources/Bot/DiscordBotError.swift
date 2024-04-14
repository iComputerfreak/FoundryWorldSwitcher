//
//  DiscordBotError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM

enum DiscordBotError: Error, LocalizedError {
    case errorReadingPermissions
    case noUser
    case unableToCreateMention(snowflake: any SnowflakeProtocol)
    
    var errorDescription: String? {
        switch self {
        case .errorReadingPermissions:
            return "There was an error reading the permissions file."
        case .noUser:
            return "There is no user associated with the command."
        case .unableToCreateMention(let snowflake):
            return "Unable to create a mention of the snowflake \(snowflake.rawValue)"
        }
    }
}
