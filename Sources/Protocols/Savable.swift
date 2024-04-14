//
//  Savable.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 01.01.24.
//

import Foundation
import Logging

/// Represents an entity that can be persisted on disk and loaded from disk again
protocol Savable: Codable {
    /// A logger associated with this entity
    static var logger: Logger { get }
    /// The URL where to persist the entity
    static var dataPath: URL { get }
    /// Loads the entity from disk
    static func load() throws -> Self
    func trySave() throws
    /// Persists the entity to disk, logging any errors
    func save()
    init()
}

extension Savable {
    /// Decodes the data stored at the `dataPath` and returns the decoded object of type `Self`.
    static func load() throws -> Self {
        guard FileManager.default.fileExists(atPath: dataPath.path) else {
            // No data available on disk, so we can create a new file
            let newObject = Self()
            do {
                try newObject.trySave()
            } catch {
                logger.warning("Error trying to save the default config to disk: \(error)")
                // We don't need to throw the error again, as this error is not critical.
                // We can continue with a config in memory
            }
            return newObject
        }
        // If the file exists, but we cannot read it, throw an error
        let data = try Data(contentsOf: dataPath)
        return try JSONDecoder().decode(Self.self, from: data)
    }
    
    static func loadOrDefault() -> Self {
        do {
            return try load()
        } catch {
            logger.error("Error loading \(String(describing: Self.self)): \(error)")
            return Self()
        }
    }
    
    /// Encodes this object into JSON data and writes it to the `dataPath` and throws any errors that occur during saving.
    func trySave() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: Self.dataPath)
    }
    
    /// Encodes this object into JSON data and writes it to the `dataPath` and logs any errors that occur during saving.
    func save() {
        do {
            try trySave()
        } catch {
            Self.logger.error("Error saving \(String(describing: Self.self)): \(error)")
        }
    }
}
