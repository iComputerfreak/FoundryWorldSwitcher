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
        let worldDirectories = try await files(in: "/data/Data/worlds/")
            .filter { !$0.isFile }
        // We now have to read the contents of the worlds' world.json file and parse it as JSON
        var worlds: [FoundryWorld] = []
        for worldDir in worldDirectories {
            worlds.append(try await world(for: worldDir.name))
        }
        return worlds
    }
    
    func world(for id: String) async throws -> FoundryWorld {
        try await fileContents(file: "/data/Data/worlds/\(id)/world.json", as: FoundryWorld.self)
    }
    
    func startServer() async throws {
        
    }
    
    func stopServer() async throws {
        
    }
    
    func restartServer() async throws {
        
    }
    
    func changeWorld(to worldID: String) async throws {
        
    }
    
    func currentWorld() async throws -> FoundryWorld? {
        guard let worldVariable = try await startupParameters()
            .variables
            .first(where: { variable in
                variable.name.lowercased() == "world name" || variable.envVariable.lowercased() == "world_name"
            })
        else {
            logger.warning(
                "Cannot find a variable with the name 'World Name' or the environment name 'WORLD_NAME' in the startup variables."
            )
            return nil
        }
        return try await world(for: worldVariable.serverValue)
    }
    
    func startupParameters() async throws -> ServerStartupParameters {
        return try await get(path: Paths.startupParameters())
    }
    
    private func files(in directory: String? = nil) async throws -> [File] {
        let response: FileListResponse = try await self.get(
            path: Paths.listFiles(),
            queryItems: [.init(name: "directory", value: directory)]
        )
        return response.files
    }
    
    // Decodes as JSON or returns the contents as string
    private func fileContents<T: Decodable>(file: String, as: T.Type = String.self) async throws -> T {
        let data: Data = try await self.get(
            path: Paths.fileContents(),
            queryItems: [.init(name: "file", value: file)]
        )
        // If we want to return a string, we just return the file contents
        if T.self == String.self {
            guard let contents = String(data: data, encoding: .utf8) else {
                throw PterodactylAPIError.cannotDecode(data, T.self)
            }
            return contents as! T
        } else {
            // Decode as JSON
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
    
    enum Paths {
        static func listFiles(serverID: String = BotConfig.shared.pterodactylServerID) -> String {
            "/servers/\(serverID)/files/list"
        }
        
        static func fileContents(serverID: String = BotConfig.shared.pterodactylServerID) -> String {
            "/servers/\(serverID)/files/contents"
        }
        
        static func startupParameters(serverID: String = BotConfig.shared.pterodactylServerID) -> String {
            "/servers/\(serverID)/startup"
        }
    }
    
    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await self.request(method: "GET", path: path, queryItems: queryItems)
    }
    
    private func post<Response: Decodable, BodyType: Encodable>(
        path: String,
        body: BodyType,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await self.request(method: "POST", path: path, body: body, queryItems: queryItems)
    }
    
    private func put<Response: Decodable, BodyType: Encodable>(
        path: String,
        body: BodyType,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await self.request(method: "PUT", path: path, body: body, queryItems: queryItems)
    }
    
    // path must start with a forward slash or baseURL has to end with one
    private func request<Response: Decodable, BodyType: Encodable>(
        method: String,
        path: String,
        body: BodyType? = nil as Data?,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        var builder = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        builder?.path.append(path)
        builder?.queryItems = queryItems
        guard let url = builder?.url else {
            throw PterodactylAPIError.invalidURL(builder?.string ?? BotConfig.shared.pterodactylHost)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        // Encode the body as JSON
        request.httpBody = try body.map(JSONEncoder().encode)
        // Set the required headers
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Application/vnd.pterodactyl.vl+json", forHTTPHeaderField: "Accept")
        
        logger.info("Performing HTTP GET request to \(request.url?.absoluteString ?? "nil")")
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
        if Response.self == Data.self {
            return data as! Response
        } else {
            return try JSONDecoder().decode(Response.self, from: data)
        }
    }
}
