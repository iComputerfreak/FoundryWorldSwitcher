//
//  Utils.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM

enum Utils {
    static func mention(of snowflake: any SnowflakeProtocol) throws -> String {
        if snowflake is UserSnowflake {
            return DiscordUtils.mention(id: snowflake as! UserSnowflake)
        } else if snowflake is RoleSnowflake {
            return DiscordUtils.mention(id: snowflake as! RoleSnowflake)
        } else if snowflake is ChannelSnowflake {
            return DiscordUtils.mention(id: snowflake as! ChannelSnowflake)
        } else {
            throw DiscordBotError.unableToCreateMention(snowflake: snowflake)
        }
    }
    
    static var baseURL: URL {
        guard let baseURL = Bundle.main.executableURL?.deletingLastPathComponent() else {
            fatalError("Unable to construct executable directory.")
        }
        return baseURL
    }
}
