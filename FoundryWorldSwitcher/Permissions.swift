//
//  Permissions.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import Foundation
import DiscordBM

struct Permissions: Codable {
    private var userMap: [UserSnowflake: BotPermissionLevel]
    private var roleMap: [RoleSnowflake: BotPermissionLevel]
    
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
    }
    
    mutating func setRolePermissionLevel(of role: RoleSnowflake, to level: BotPermissionLevel) {
        roleMap[role] = level
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
    
    static let permissionsFile = Bundle.main.executableURL?
        .deletingLastPathComponent()
        .appending(component: "permissions.json")
    
    static func load() throws -> Self {
        guard let permissionsFile else {
            throw DiscordBotError.errorReadingPermissions
        }
        let data = try Data(contentsOf: permissionsFile)
        return try JSONDecoder().decode(Self.self, from: data)
    }
    
    func save() throws {
        guard let permissionsFile = Self.permissionsFile else {
            throw DiscordBotError.errorReadingPermissions
        }
        let data = try JSONEncoder().encode(self)
        try data.write(to: permissionsFile)
    }
}
