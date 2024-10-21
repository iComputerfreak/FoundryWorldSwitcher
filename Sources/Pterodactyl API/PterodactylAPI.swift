//
//  PterodactylAPI.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation
import Logging

actor PterodactylAPI {
    static let shared: PterodactylAPI = {
        do {
            return try .init()
        } catch {
            fatalError("Unable to create base URL for Pterodactyl API: \(error)")
        }
    }()
    
    let logger = Logger(label: "PterodactylAPI")
    private let apiKey: String = Secrets.shared.pterodactylAPIKey
    let baseURL: URL
    
    // Cache
    private var worldsTTL: Date?
    private var _cachedWorlds: [FoundryWorld]?
    private(set) var cachedWorlds: [FoundryWorld]? {
        get {
            guard let worldsTTL, worldsTTL > .now else {
                return nil
            }
            return _cachedWorlds
        }
        set {
            _cachedWorlds = newValue
            worldsTTL = .now.addingTimeInterval(GlobalConstants.secondsPerDay)
        }
    }
    
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
        if let cachedWorlds {
            return cachedWorlds
        }
        
        let worldDirectories = try await files(in: "/data/Data/worlds/")
            .filter { !$0.isFile }
        let worldIDs = worldDirectories.map(\.name)
        
        // We now have to read the contents of the worlds' world.json file and parse it as JSON
        var worlds: [FoundryWorld] = []
        for worldID in worldIDs {
            worlds.append(try await fileContents(file: "/data/Data/worlds/\(worldID)/world.json", as: FoundryWorld.self))
        }
        self.cachedWorlds = worlds
        return worlds
    }
    
    func world(for id: String) async throws -> FoundryWorld {
        guard let world = try await worlds().first(where: { $0.id.lowercased() == id.lowercased() }) else {
            throw PterodactylAPIError.worldDoesNotExist(id)
        }
        return world
    }
    
    func startServer() async throws {
        try await serverPowerAction(action: .start)
    }
    
    func stopServer() async throws {
        try await serverPowerAction(action: .stop)
    }
    
    func restartServer() async throws {
        try await serverPowerAction(action: .restart)
    }
    
    func serverPowerAction(action: PterodactylServerPowerAction) async throws {
        let _: Data = try await post(path: Paths.serverPowerAction(), body: ["signal": action.rawValue])
    }
    
    func changeWorld(to worldID: String, restart: Bool) async throws {
        let _: Data = try await put(path: Paths.modifyStartupVariable(), body: [
            "key": "WORLD_NAME",
            "value": worldID
        ])
        if restart {
            try await restartServer()
        }
    }
    
    func currentWorld() async throws -> FoundryWorld {
        guard let worldVariable = try await startupParameters()
            .variables
            .first(where: { variable in
                variable.name.lowercased() == "world name" || variable.envVariable.lowercased() == "world_name"
            })
        else {
            throw PterodactylAPIError.noWorldVariable
        }
        return try await world(for: worldVariable.serverValue)
    }
    
    func startupParameters() async throws -> ServerStartupParameters {
        return try await get(path: Paths.startupParameters())
    }
    
    func files(in directory: String? = nil) async throws -> [File] {
        let response: FileListResponse = try await self.get(
            path: Paths.listFiles(),
            queryItems: [.init(name: "directory", value: directory)]
        )
        return response.files
    }
    
    func downloadLink(for file: String) async throws -> String {
        let response: FileDownloadLinkResponse = try await self.get(
            path: Paths.fileDownloadLink(),
            queryItems: [.init(name: "file", value: file)]
        )
        return response.url
    }
    
    // Decodes as JSON or returns the contents as string
    func fileContents<T: Decodable>(file: String, as: T.Type = String.self) async throws -> T {
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
        
        static func fileDownloadLink(serverID: String = BotConfig.shared.pterodactylServerID) -> String {
            "/servers/\(serverID)/files/download"
        }
        
        static func serverPowerAction(serverID: String = BotConfig.shared.pterodactylServerID) -> String {
            "/servers/\(serverID)/power"
        }
        
        static func modifyStartupVariable(serverID: String = BotConfig.shared.pterodactylServerID) -> String {
            "/servers/\(serverID)/startup/variable"
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
        let queryItems = queryItems.isEmpty ? nil : queryItems
        
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
        let (data, response) = try await self.dataRequest(request)
        
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
    
    // Uses a continuation to make the old completion handler DataSession syntax async/await-ready on Linux
    private func dataRequest(_ request: URLRequest) async throws -> (data: Data, response: URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if response == nil || data == nil {
                    continuation.resume(throwing: PterodactylAPIError.emptyResponse)
                    return
                }
                continuation.resume(returning: (data!, response!))
            }
            task.resume()
        }
    }
}

// MARK: - Caching
extension PterodactylAPI {
    func updateCache() async throws {
        invalidateCache()
        // Update the cache by fetching the worlds
        _ = try await worlds()
    }
    
    func invalidateCache() {
        worldsTTL = nil
    }
}
