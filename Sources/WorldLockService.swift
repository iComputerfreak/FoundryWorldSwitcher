//
//  WorldLockService.swift
//
//
//  Created by Jonas Frey on 13.04.24.
//

import Foundation
import Logging

enum WorldLockError: LocalizedError {
    case unableToCreateFile
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateFile:
            return "Unable to create the file on disk."
        }
    }
}

class WorldLockService {
    static var lockFilePath: URL = Utils.dataURL.appendingPathComponent(".worldlock")
    static let shared = WorldLockService()
    
    let fileManager = FileManager.default
    
    func lockWorldSwitching() throws {
        guard fileManager.createFile(atPath: Self.lockFilePath.path(), contents: nil) else {
            throw WorldLockError.unableToCreateFile
        }
    }
    
    func unlockWorldSwitching() throws {
        try fileManager.removeItem(at: Self.lockFilePath)
    }
    
    func isWorldSwitchingLocked() -> Bool {
        fileManager.fileExists(atPath: Self.lockFilePath.path())
    }
}
