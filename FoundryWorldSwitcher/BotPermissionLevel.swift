//
//  BotPermissionLevel.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

enum BotPermissionLevel: CustomStringConvertible, Codable {
    case user
    case dungeonMaster
    case admin
    
    var description: String {
        switch self {
        case .user:
            return "User"
        case .dungeonMaster:
            return "Dungeon Master"
        case .admin:
            return "Admin"
        }
    }
}
