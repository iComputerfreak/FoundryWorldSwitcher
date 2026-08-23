//
//  WorldLockService.swift
//
//
//  Created by Jonas Frey on 13.04.24.
//

import DiscordBM
import Foundation
import Logging

enum WorldLockError: LocalizedError {
    case alreadyLocked
    
    var errorDescription: String? {
        switch self {
        case .alreadyLocked:
            return "World switching is already locked."
        }
    }
}

struct WorldLockRecord: Codable, Hashable {
    let guildID: GuildSnowflake?
    let bookingID: UUID?
    let acquiredAt: Date
}

final class WorldLockService {
    static var lockFilePath: URL = Utils.dataURL.appendingPathComponent("world-lock.json")
    static let shared: WorldLockService = .init()
    
    private let fileManager = FileManager.default
    private let lock = NSLock()
    
    @discardableResult
    func lockWorldSwitching() throws -> WorldLockRecord {
        try writeLock(guildID: nil, bookingID: nil)
    }

    @discardableResult
    func lockWorldSwitching(guildID: GuildSnowflake, bookingID: UUID) throws -> WorldLockRecord {
        try writeLock(guildID: guildID, bookingID: bookingID)
    }
    
    func unlockWorldSwitching() throws {
        lock.lock()
        defer { lock.unlock() }
        guard isWorldSwitchingLocked() else { return }
        try fileManager.removeItem(at: Self.lockFilePath)
    }

    @discardableResult
    func unlockWorldSwitching(guildID: GuildSnowflake, bookingID: UUID) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let record = try record(), record.guildID == guildID, record.bookingID == bookingID else {
            return false
        }
        try fileManager.removeItem(at: Self.lockFilePath)
        return true
    }

    @discardableResult
    func unlockManualWorldSwitching(acquiredAt: Date) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard
            let record = try record(),
            record.guildID == nil,
            record.bookingID == nil,
            record.acquiredAt == acquiredAt
        else {
            return false
        }
        try fileManager.removeItem(at: Self.lockFilePath)
        return true
    }
    
    func isWorldSwitchingLocked() -> Bool {
        fileManager.fileExists(atPath: Self.lockFilePath.path)
    }

    private func writeLock(guildID: GuildSnowflake?, bookingID: UUID?) throws -> WorldLockRecord {
        lock.lock()
        defer { lock.unlock() }
        guard !isWorldSwitchingLocked() else { throw WorldLockError.alreadyLocked }

        let record = WorldLockRecord(guildID: guildID, bookingID: bookingID, acquiredAt: .now)
        try JSONEncoder().encode(record).write(to: Self.lockFilePath)
        return record
    }

    private func record() throws -> WorldLockRecord? {
        guard isWorldSwitchingLocked() else { return nil }
        return try JSONDecoder().decode(WorldLockRecord.self, from: Data(contentsOf: Self.lockFilePath))
    }
}
