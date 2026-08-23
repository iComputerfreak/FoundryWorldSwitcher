//
//  BotConfig.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import DiscordBM
import Foundation
import Logging

/// Keys accepted by the configuration command.
enum ConfigKey: String, CaseIterable {
    case pterodactylHost
    case pterodactylServerID
    case sessionLength
    case bookingIntervalStartTime
    case bookingIntervalEndTime
    case sessionReminderTime
    case shouldNotifyAtSessionStart
    case sessionStartReminderTime
    case reminderChannel
    case foundryFeaturesEnabled
}

/// Global Pterodactyl target configuration persisted at `data/botConfig.json`.
final class BotConfig: Savable {
    static let logger = Logger(label: "BotConfig")
    static let dataPath = Utils.dataURL.appendingPathComponent("botConfig.json")
    static let shared: BotConfig = .loadOrDefault()

    /// The hostname of the Pterodactyl panel.
    var pterodactylHost: String {
        didSet { save() }
    }

    /// The ID of the server on the Pterodactyl panel.
    var pterodactylServerID: String {
        didSet { save() }
    }

    init(pterodactylHost: String, pterodactylServerID: String) {
        self.pterodactylHost = pterodactylHost
        self.pterodactylServerID = pterodactylServerID
    }

    required convenience init() {
        self.init(pterodactylHost: "", pterodactylServerID: "")
    }

    required convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pterodactylHost: try container.decodeIfPresent(String.self, forKey: .pterodactylHost) ?? "",
            pterodactylServerID: try container.decodeIfPresent(String.self, forKey: .pterodactylServerID) ?? ""
        )
    }
}
