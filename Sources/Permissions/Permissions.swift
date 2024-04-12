//
//  Permissions.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import Foundation
import DiscordBM
import Logging

// TODO: Make Savable
struct Permissions: Codable {
    private static let logger = Logger(label: "Permissions")
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
    
    init() {
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
    
    mutating func setUserPermissionLevel(of user: UserSnowflake, to level: BotPermissionLevel) {
        userMap[user] = level
        self.save()
    }
    
    mutating func setRolePermissionLevel(of role: RoleSnowflake, to level: BotPermissionLevel) {
        roleMap[role] = level
        self.save()
    }
    
    mutating func setPermissionLevel(of user: UserSnowflake, to level: BotPermissionLevel) {
        setUserPermissionLevel(of: user, to: level)
    }
    
    mutating func setPermissionLevel(of role: RoleSnowflake, to level: BotPermissionLevel) {
        setRolePermissionLevel(of: role, to: level)
    }
    
    // MARK: - Persisting
    
    static var shared: Self = {
        do {
            return try Self.load()
        } catch {
            logger.error("Error reading permissions file. Falling back to empty permissions: \(error)")
            return Self()
        }
    }()
    
    static let permissionsFile = Utils.configURL.appendingPathComponent("permissions.json")
    
    static func load() throws -> Self {
        // If there is no config file, we create a new one
        guard FileManager.default.fileExists(atPath: permissionsFile.path) else {
            let newPermissions = Self()
            newPermissions.save()
            return newPermissions
        }
        let data = try Data(contentsOf: permissionsFile)
        return try JSONDecoder().decode(Self.self, from: data)
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: Self.permissionsFile)
        } catch {
            Self.logger.error("Error saving permissions: \(error)")
        }
    }
}
