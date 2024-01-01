//
//  PterodactylAPI.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation

struct PterodactylAPI {
    let apiKey: String = Secrets.shared.pterodactylAPIKey
    
    func worlds() async throws -> [FoundryWorld] {
        return []
    }
    
    func startServer() async throws {
        
    }
    
    func stopServer() async throws {
        
    }
    
    func restartServer() async throws {
        
    }
    
    func changeWorld(to worldID: String) async throws {
        
    }
    
    private func files(in directory: String? = nil) -> [File] {
        
    }
    
    private func fileContents(file: String) -> String {
        
    }
    
    private func request<T: Decodable>(path: String, arguments: [URLQueryItem]) -> T {
        
    }
}
