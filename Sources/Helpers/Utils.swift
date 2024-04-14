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
    
    /// The URL pointing to the directory the executable file is in.
    /// Crashes the program, if the app is unable to determine the base path.
    static var baseURL: URL {
        guard let baseURL = Bundle.main.executableURL?.deletingLastPathComponent() else {
            fatalError("Unable to construct executable directory.")
        }
        return baseURL
    }
    
    static var dataURL: URL {
        let configURL = baseURL.appendingPathComponent("data")
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
    
    static func formatBooking(_ booking: any Booking) -> String {
        let date = booking.date
        let author = booking.author
        let world = booking.worldID
        
        let activityString: String
        if let eventBooking = booking as? EventBooking {
            let group = eventBooking.campaignRoleSnowflake
            let topic = eventBooking.topic
            activityString = "\(DiscordUtils.mention(id: group)) is playing on the world \(world)\n> \(topic)"
        } else {
            activityString = "\(DiscordUtils.mention(id: author)) is preparing the world \(world)"
        }
        
        // Sunday, 01.01.2024 at 18:00
        // @Role is playing on the world TWBTW
        // *Session 13*
        return """
        **\(date.formatted(date: .complete, time: booking is EventBooking ? .shortened : .omitted))**
        \(activityString)
        """
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
