//
//  FoundryWorld.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation

struct FoundryWorld: Decodable {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z (zzzz)"
        return f
    }()
    
    let title: String
    let id: String
    let system: String
    let coreVersion: String
    let systemVersion: String
    let backgroundPath: String?
    let lastPlayed: Date?
    let playTime: Int?
    let description: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        if let id = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        } else {
            // Fall back to the old 'name' key
            guard let id = try container.decodeIfPresent(String.self, forKey: .name) else {
                throw Swift.DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: [CodingKeys.id], debugDescription: "Neither the key 'id', nor the key 'name' is present in the data."))
            }
            self.id = id
        }
        self.system = try container.decode(String.self, forKey: .system)
        self.coreVersion = try container.decode(String.self, forKey: .coreVersion)
        self.systemVersion = try container.decode(String.self, forKey: .systemVersion)
        self.backgroundPath = try container.decodeIfPresent(String.self, forKey: .backgroundPath)
        if let lastPlayedString = try container.decodeIfPresent(String.self, forKey: .lastPlayed) {
            self.lastPlayed = Self.dateFormatter.date(from: lastPlayedString)
        } else {
            self.lastPlayed = nil
        }
        self.playTime = try container.decodeIfPresent(Int.self, forKey: .playTime)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case id, name
        case system
        case coreVersion
        case systemVersion
        case backgroundPath = "background"
        case lastPlayed
        case playTime
        case description
    }
}
