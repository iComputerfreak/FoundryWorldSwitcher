//
//  EggVariable.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation

struct EggVariable: Decodable {
    let name: String
    let description: String
    let envVariable: String
    let defaultValue: String
    let serverValue: String
    let isEditable: Bool
    let rules: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case envVariable = "env_variable"
        case defaultValue = "default_value"
        case serverValue = "server_value"
        case isEditable = "is_editable"
        case rules
    }
    
    enum RootCodingKeys: String, CodingKey {
        case attributes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootCodingKeys.self)
            .nestedContainer(keyedBy: CodingKeys.self, forKey: .attributes)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.envVariable = try container.decode(String.self, forKey: .envVariable)
        self.defaultValue = try container.decode(String.self, forKey: .defaultValue)
        self.serverValue = try container.decode(String.self, forKey: .serverValue)
        self.isEditable = try container.decode(Bool.self, forKey: .isEditable)
        self.rules = try container.decode(String.self, forKey: .rules)
    }
}
