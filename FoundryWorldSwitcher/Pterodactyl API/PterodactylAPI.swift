//
//  PterodactylAPI.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import Logging
import JFUtils

struct PterodactylAPI {
    static let shared: Self = {
        do {
            return try Self()
        } catch {
            fatalError("Unable to create base URL for Pterodactyl API: \(error)")
        }
    }()
    
    let logger = Logger(label: "PterodactylAPI")
    private let apiKey: String = Secrets.shared.pterodactylAPIKey
    let baseURL: URL
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    init() throws {
        var builder = URLComponents(string: BotConfig.shared.pterodactylHost)
        builder?.path = "/api/client"
        guard let url = builder?.url else {
            // If the builder string is nil, the pterodactyl host must be the problem
            throw PterodactylAPIError.invalidURL(builder?.string ?? BotConfig.shared.pterodactylHost)
        }
        self.init(baseURL: url)
    }
    
    func worlds() async throws -> [FoundryWorld] {
        let response: FileListResponse = try await self.request(
            path: Paths.listFiles(),
            queryItems: [.init(name: "directory", value: "/data/Data/worlds/")]
        )
        return response.files.filter { !$0.isFile }.map { file in
            FoundryWorld(id: file.name, name: file.name)
        }
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
        return []
    }
    
    private func fileContents(file: String) -> String {
        return ""
    }
    
    enum Paths {
        static func listFiles(serverID: String = BotConfig.shared.pterodactylServerID) -> String {
            "/servers/\(serverID)/files/list"
        }
    }
    
    // path must start with a forward slash or baseURL has to end with one
    private func request<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var builder = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        builder?.path.append(path)
        builder?.queryItems = queryItems
        guard let url = builder?.url else {
            throw PterodactylAPIError.invalidURL(builder?.string ?? BotConfig.shared.pterodactylHost)
        }
        var request = URLRequest(url: url)
        // Set the required headers
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Application/vnd.pterodactyl.vl+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PterodactylAPIError.invalidHTTPResponse(data)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            logger.error(
                "HTTP Request returned code \(httpResponse.statusCode):\n\(String(data: data, encoding: .utf8) ?? "nil")"
            )
            throw PterodactylAPIError.invalidResponseCode(httpResponse.statusCode)
        }
        
        // MARK: Decode the data
        return try JSONDecoder().decode(T.self, from: data)
    }
}
