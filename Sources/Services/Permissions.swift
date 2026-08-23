//
//  Permissions.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import Foundation
import DiscordBM
import Logging

/// Guild-local permission mappings with non-persisted application-owner access.
final class Permissions {
    /// Logger for permission persistence failures.
    static let logger = Logger(label: "Permissions")

    /// User-specific permission levels persisted for this guild.
    private var userMap: [UserSnowflake: BotPermissionLevel]

    /// Role-specific permission levels persisted for this guild.
    private var roleMap: [RoleSnowflake: BotPermissionLevel]

    /// Application owner granted non-persisted administrator access.
    private let applicationOwnerID: UserSnowflake?
    /// File containing this guild's persisted mappings.
    private let dataPath: URL

    /// Users explicitly granted administrator permission in this guild.
    var adminUsers: [UserSnowflake] {
        filter(userMap, level: .admin)
    }
    
    /// Roles explicitly granted administrator permission in this guild.
    var adminRoles: [RoleSnowflake] {
        filter(roleMap, level: .admin)
    }
    
    /// Users explicitly granted Dungeon Master permission in this guild.
    var dungeonMasterUsers: [UserSnowflake] {
        filter(userMap, level: .dungeonMaster)
    }
    
    /// Roles explicitly granted Dungeon Master permission in this guild.
    var dungeonMasterRoles: [RoleSnowflake] {
        filter(roleMap, level: .dungeonMaster)
    }
    
    /// Returns sorted IDs whose mapping equals `level`.
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
    
    /// Loads persisted mappings and registers the runtime-only application owner.
    init(dataPath: URL, applicationOwnerID: UserSnowflake?) {
        self.dataPath = dataPath
        self.applicationOwnerID = applicationOwnerID
        let stored = Self.load(from: dataPath)
        self.userMap = stored.userMap
        self.roleMap = stored.roleMap
    }
    
    /// Returns the user's direct level, elevating application owners to admin.
    func userPermissionLevel(of user: UserSnowflake) -> BotPermissionLevel {
        if isApplicationOwner(user) {
            return .admin
        }
        return userMap[user, default: .user]
    }

    /// Returns whether `user` owns the Discord application for this process.
    func isApplicationOwner(_ user: UserSnowflake) -> Bool {
        applicationOwnerID == user
    }
    
    /// Returns the persisted permission level for `role`.
    func rolePermissionLevel(of role: RoleSnowflake) -> BotPermissionLevel {
        return roleMap[role, default: .user]
    }
    
    /// Returns the highest user or role level, elevating application owners to admin.
    func permissionsLevel(of user: UserSnowflake, roles: [RoleSnowflake]) -> BotPermissionLevel {
        let permissions =  [userPermissionLevel(of: user)] + roles.map { rolePermissionLevel(of: $0) }
        return permissions.max(by: <) ?? .user
    }
    
    /// Persists `level` for `user` in this guild.
    func setUserPermissionLevel(of user: UserSnowflake, to level: BotPermissionLevel) {
        userMap[user] = level
        save()
    }
    
    /// Persists `level` for `role` in this guild.
    func setRolePermissionLevel(of role: RoleSnowflake, to level: BotPermissionLevel) {
        roleMap[role] = level
        save()
    }
    
    /// Persists `level` for `user` in this guild.
    func setPermissionLevel(of user: UserSnowflake, to level: BotPermissionLevel) {
        setUserPermissionLevel(of: user, to: level)
    }
    
    /// Persists `level` for `role` in this guild.
    func setPermissionLevel(of role: RoleSnowflake, to level: BotPermissionLevel) {
        setRolePermissionLevel(of: role, to: level)
    }

    /// Writes current guild mappings to disk.
    private func save() {
        do {
            let stored = Stored(userMap: userMap, roleMap: roleMap)
            try JSONEncoder().encode(stored).write(to: dataPath)
        } catch {
            Self.logger.error("Error saving permissions: \(error)")
        }
    }

    /// Loads persisted guild mappings, returning empty mappings when unavailable.
    private static func load(from dataPath: URL) -> Stored {
        guard FileManager.default.fileExists(atPath: dataPath.path) else {
            return .init(userMap: [:], roleMap: [:])
        }
        do {
            return try JSONDecoder().decode(Stored.self, from: Data(contentsOf: dataPath))
        } catch {
            logger.error("Error loading permissions: \(error)")
            return .init(userMap: [:], roleMap: [:])
        }
    }
}

/// Codable form of guild-local permission mappings.
private struct Stored: Codable {
    let userMap: [UserSnowflake: BotPermissionLevel]
    let roleMap: [RoleSnowflake: BotPermissionLevel]
}
