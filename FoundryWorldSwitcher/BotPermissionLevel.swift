//
//  BotPermissionLevel.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

enum BotPermissionLevel: Int, CustomStringConvertible, Codable, Comparable, CaseIterable {
    case user = 0
    case dungeonMaster = 1
    case admin = 2
    
    static func < (lhs: BotPermissionLevel, rhs: BotPermissionLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
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
