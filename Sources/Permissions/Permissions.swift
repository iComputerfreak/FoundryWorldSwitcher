//
//  Permissions.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import Foundation
import DiscordBM
import Logging

class Permissions: Savable {
    static let logger = Logger(label: "Permissions")
    static var dataPath: URL = Utils.dataURL.appendingPathComponent("permissions.json")
    static let shared: Permissions = .init()
    
    private var userMap: [UserSnowflake: BotPermissionLevel]
    private var roleMap: [RoleSnowflake: BotPermissionLevel]
    
    var adminUsers: [UserSnowflake] {
        filter(userMap, level: .admin)
    }
    
    var adminRoles: [RoleSnowflake] {
        filter(roleMap, level: .admin)
    }
    
    var dungeonMasterUsers: [UserSnowflake] {
        filter(userMap, level: .dungeonMaster)
    }
    
    var dungeonMasterRoles: [RoleSnowflake] {
        filter(roleMap, level: .dungeonMaster)
    }
    
    private func filter<SnowflakeType: SnowflakeProtocol>(
        _ dict: [SnowflakeType: BotPermissionLevel],
        level: BotPermissionLevel
    ) -> [SnowflakeType] {
        dict.filter { (_, value: BotPermissionLevel) in
            value == level
        }
        .map { (key, _) in
            key
        }
        .sorted { $0.rawValue < $1.rawValue }
    }
    
    required init() {
        self.userMap = [:]
        self.roleMap = [:]
    }
    
    func userPermissionLevel(of user: UserSnowflake) -> BotPermissionLevel {
        return userMap[user, default: .user]
    }
    
    func rolePermissionLevel(of role: RoleSnowflake) -> BotPermissionLevel {
        return roleMap[role, default: .user]
    }
    
    func permissionsLevel(of user: UserSnowflake, roles: [RoleSnowflake]) -> BotPermissionLevel {
        let permissions =  [userPermissionLevel(of: user)] + roles.map { rolePermissionLevel(of: $0) }
        return permissions.max(by: <) ?? .user
    }
    
    func setUserPermissionLevel(of user: UserSnowflake, to level: BotPermissionLevel) {
        userMap[user] = level
        self.save()
    }
    
    func setRolePermissionLevel(of role: RoleSnowflake, to level: BotPermissionLevel) {
        roleMap[role] = level
        self.save()
    }
    
    func setPermissionLevel(of user: UserSnowflake, to level: BotPermissionLevel) {
        setUserPermissionLevel(of: user, to: level)
    }
    
    func setPermissionLevel(of role: RoleSnowflake, to level: BotPermissionLevel) {
        setRolePermissionLevel(of: role, to: level)
    }
}
