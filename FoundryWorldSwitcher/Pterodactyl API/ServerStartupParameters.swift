//
//  ServerStartupParameters.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation

struct ServerStartupParameters: Decodable {
    let variables: [EggVariable]
    let startupCommand: String
    let rawStartupCommand: String
    
    enum CodingKeys: CodingKey {
        case data
        case meta
    }
    
    enum MetaCodingKeys: String, CodingKey {
        case startupCommand = "startup_command"
        case rawStartupCommand = "raw_startup_command"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.variables = try container.decode([EggVariable].self, forKey: .data)
        let metaContainer = try container.nestedContainer(keyedBy: MetaCodingKeys.self, forKey: .meta)
        self.startupCommand = try metaContainer.decode(String.self, forKey: .startupCommand)
        self.rawStartupCommand = try metaContainer.decode(String.self, forKey: .rawStartupCommand)
    }
}
