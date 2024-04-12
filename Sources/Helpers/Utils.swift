//
//  Utils.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM
import Logging

enum Utils {
    private static let logger = Logger(label: "Utils")
    
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
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
    
    /// The URL pointing to the directory the executable file is in.
    /// Crashes the program, if the app is unable to determine the base path.
    static var baseURL: URL {
        guard let baseURL = Bundle.main.executableURL?.deletingLastPathComponent() else {
            fatalError("Unable to construct executable directory.")
        }
        return baseURL
    }
    
    static var configURL: URL {
        let configURL = baseURL.appendingPathComponent("config")
        var isDirectory: ObjCBool = false
        // If the config directory does not exist or it is not a directory, create a new one
        if !FileManager.default.fileExists(atPath: configURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            do {
                try FileManager.default.createDirectory(at: configURL, withIntermediateDirectories: true)
            } catch {
                logger.error("Error creating config directory: \(error)")
            }
        }
        return configURL
    }
    
    /// Tries to parse and return a `FoundryWorld` from the given command's arguments.
    /// Returns `nil`, if no argument is present or the argument's value is empty
    static func parseWorld(from command: Interaction.ApplicationCommand, optionName: String = "world_id") async throws -> FoundryWorld? {
        guard let worldArg = command.option(named: optionName)?.value, !worldArg.asString.isEmpty else {
            // No argument given or argument is empty
            return nil
        }
        let worldID = try worldArg.requireString()
        
        let allWorlds = try await PterodactylAPI.shared.worldIDs()
        print(allWorlds)
        guard allWorlds.contains(worldID) else {
            throw DiscordCommandError.worldDoesNotExist(worldID: worldID)
        }
        
        do {
            return try await PterodactylAPI.shared.world(for: worldID)
        } catch PterodactylAPIError.invalidResponseCode(let code) {
            // If we get a 500 error, maybe the world ID does not exist.
            Self.logger.error("Error getting world information for world `\(worldArg)`. HTTP Request returned code \(code)")
            throw PterodactylAPIError.invalidResponseCode(code)
        }
    }
}
