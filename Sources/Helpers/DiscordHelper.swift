//
//  DiscordHelper.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

enum DiscordHelper {
    /// Returns a mention for the given Snowflake
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
}
