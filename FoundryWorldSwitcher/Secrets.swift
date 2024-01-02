//
//  Secrets.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import Logging

struct Secrets: Savable {
    static var dataPath: URL = Utils.baseURL.appending(component: "secrets.json")
    static let shared = {
        do {
            return try Self.load()
        } catch {
            logger.critical("Unable to load secrets! \(error)")
            fatalError("The bot is missing at least one of the two required secrets. Make sure that the Discord bot token and Pterodactyl API token are both present.")
        }
    }()
    static let logger = Logger(label: "Secrets")
    
    // Secrets are read-only for now.
    let botToken: String
    let pterodactylAPIKey: String
    
    init(botToken: String, pterodactylAPIKey: String) {
        self.botToken = botToken
        self.pterodactylAPIKey = pterodactylAPIKey
    }
    
    init() {
        self.init(
            botToken: "< PUT YOUR DISCORD BOT TOKEN HERE >",
            pterodactylAPIKey: "< PUT YOUR PTERODACTYL API KEY HERE >"
        )
    }
    
    static func load() throws -> Self {
        // Fall back to the current working directory
        guard let baseURL = Bundle.main.executableURL?.deletingLastPathComponent() else {
            throw SecretsError.cannotCreateFilePath
        }
        return Self(
            botToken: try loadSecret(baseURL: baseURL, fileName: "BOT_TOKEN", environmentName: "FOUNDRY_BOT_TOKEN"),
            pterodactylAPIKey: try loadSecret(baseURL: baseURL, fileName: "PTERODACTYL_API_KEY", environmentName: "FOUNDRY_PTERODACTYL_TOKEN")
        )
    }
    
    static func loadSecret(baseURL: URL, fileName: String, environmentName: String) throws -> String {
        if FileManager.default.fileExists(atPath: baseURL.appending(component: fileName).path()) {
            do {
                // Try getting the secret from a file
                return try loadSecretFromFile(baseURL: baseURL, fileName: fileName)
            } catch {
                logger.warning("Did not load the secret from the file: \(error)")
            }
        }
        do {
            return try loadSecretFromEnvironment(environmentName)
        } catch {
            logger.warning("Did not load the secret from the environment: \(error)")
        }
        // If we are still here, both methods did not succeed
        logger.error("Unable to load the secret from either the file or environment variable.")
        throw SecretsError.noSecretFound(baseURL: baseURL, fileName: fileName, environmentName: environmentName)
    }
    
    static func loadSecretFromFile(baseURL: URL, fileName: String) throws -> String {
        let contents = try String(contentsOf: baseURL.appending(component: fileName))
        guard !contents.isEmpty else {
            throw SecretsError.emptySecret
        }
        return try cleanSecret(contents)
    }
    
    static func loadSecretFromEnvironment(_ environmentName: String) throws -> String {
        let value = ProcessInfo.processInfo.environment[environmentName, default: ""]
        guard !value.isEmpty else {
            throw SecretsError.emptySecret
        }
        return try cleanSecret(value)
    }
    
    static private func cleanSecret(_ secret: String) throws -> String {
        guard let secret = secret.components(separatedBy: .newlines).first else {
            throw SecretsError.emptySecret
        }
        return secret
    }
}
