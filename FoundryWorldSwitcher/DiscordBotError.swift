//
//  DiscordBotError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM

enum DiscordBotError: Error {
    case errorReadingPermissions
    case noUser
    case noToken
    case unableToCreateMention(snowflake: any SnowflakeProtocol)
    case unexpected(_ reason: String)
}
