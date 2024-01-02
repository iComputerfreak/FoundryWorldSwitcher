//
//  SecretsError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation

enum SecretsError: Error {
    case cannotCreateFilePath
    case emptySecret
    case noSecretFound(baseURL: URL, fileName: String, environmentName: String)
}
