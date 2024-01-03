//
//  BotConfig.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import Logging

struct BotConfig: Savable {
    static let logger = Logger(label: "BotConfig")
    static let dataPath = Utils.baseURL.appendingPathComponent("botConfig.json")
    static let shared: Self = {
        do {
            return try Self.load()
        } catch {
            // No sense in continuing without a valid bot config
            fatalError("Error reading bot config file: \(error). To recreate the default config, delete or rename the corrupt file.")
        }
        return Self()
    }()
    
    // For now, we keep everything read only and let the user edit the .json.
    // This means we don't need to save either.
    let pterodactylHost: String
    let pterodactylServerID: String
    
    init(pterodactylHost: String, pterodactylServerID: String) {
        self.pterodactylHost = pterodactylHost
        self.pterodactylServerID = pterodactylServerID
    }
    
    init() {
        self.init(pterodactylHost: "http://127.0.0.1", pterodactylServerID: "")
    }
    
}
