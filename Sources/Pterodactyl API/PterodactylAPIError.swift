//
//  PterodactylAPIError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation

enum PterodactylAPIError: Error, LocalizedError {
    case invalidURL(String)
    case invalidHTTPResponse(Data)
    case invalidResponseCode(Int)
    case cannotDecode(Data, Any.Type)
    case noWorldVariable
    case cannotFindWorld(String)
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let string):
            return "Error creating an URL from the String '\(string)'"
        case .invalidHTTPResponse(let data):
            return "The HTTP Response is invalid: \(String(data: data, encoding: .utf8) ?? "nil")"
        case .invalidResponseCode(let code):
            return "The HTTP Request returned a non-success response code \(code)."
        case .cannotDecode(let data, let type):
            return "Unable to decode the following data as type \(String(describing: type)):\n\(String(data: data, encoding: .utf8) ?? "nil")"
        case .noWorldVariable:
            return "Cannot find a variable with the name 'World Name' or the environment name 'WORLD_NAME' in the startup variables."
        case .cannotFindWorld(let worldID):
            return "Cannot find a world with the ID '\(worldID)'."
        case .emptyResponse:
            return "The HTTP response returned empty data."
        }
    }
}
