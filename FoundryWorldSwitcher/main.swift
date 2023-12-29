//
//  main.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import Foundation
import DiscordBM
import AsyncHTTPClient
import Logging

enum DiscordBotError: Error {
    case errorFindingAppDirectory
    case errorReadingPermissions
    case noUser
    case unableToCreateMention(snowflake: any SnowflakeProtocol)
}

let logger = Logger(label: "Main")

// We read the bot token from a file called `BOT_TOKEN` or an environment variable called `FOUNDRY_BOT_TOKEN`
guard let appDirectory = Bundle.main.executableURL?.deletingLastPathComponent() else {
    throw DiscordBotError.errorFindingAppDirectory
}
logger.debug("App directory: \(appDirectory.path())")
let tokenFile = appDirectory.appending(component: "BOT_TOKEN").path()

var botToken: String? = nil
if FileManager.default.fileExists(atPath: tokenFile) {
    do {
        botToken = try String(contentsOfFile: tokenFile)
    } catch {
        logger.error("Error reading BOT_TOKEN file. Falling back to environment variable.\n\(error)")
    }
}
// We read the environment variable if reading the BOT_TOKEN file failed
if botToken == nil {
    botToken = ProcessInfo.processInfo.environment["FOUNDRY_BOT_TOKEN"]
}

guard let botToken = botToken?.components(separatedBy: .newlines).first else {
    logger.error(
        "Error reading bot token. Please provide the bot's token in a file called `BOT_TOKEN` next to the executable or in an environment variable called `FOUNDRY_BOT_TOKEN`."
    )
    exit(1)
}

let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

let bot = await BotGatewayManager(
    eventLoopGroup: httpClient.eventLoopGroup,
    httpClient: httpClient,
    token: botToken,
    presence: .init(
        /// Will show up as "Playing Foundry VTT"
        activities: [.init(name: "Foundry VTT", type: .game)],
        status: .online,
        afk: false
    ),
    /// Add all the intents you want
    /// You can also use `Gateway.Intent.unprivileged` or `Gateway.Intent.allCases`
    intents: []
)

/// Tell the manager to connect to Discord. Use a `Task { }` because it
/// might take a few seconds, or even minutes under bad network connections
/// Don't use `Task { }` if you care and want to wait
Task {
    await bot.connect()
    
    // Give the bot owner admin permissions
    do {
        let botApplication = try await bot.client.getOwnApplication().decode()
        guard let ownerID = botApplication.owner?.id else {
            logger.warning("Error determining the bot owner. Will not give the bot owner admin permissions.")
            return
        }
        Permissions.shared.setUserPermissionLevel(of: ownerID, to: .admin)
    } catch {
        logger.warning("Error determining the bot owner. Will not give the bot owner admin permissions. \(error)")
    }
}

/// Register commands
let commands: [DiscordCommand] = [
    HelloCommand(),
    MyPermissionsCommand(),
    SetPermissionLevel(),
    ShowPermissionsCommand()
]

try await bot.client
    .bulkSetApplicationCommands(payload: commands.map { $0.createApplicationCommand() } )
    .guardSuccess() // Throw an error if not successful

/// Handle each event in the `bot.events` async stream
/// This stream will never end, therefore preventing your executable from exiting
for await event in await bot.events {
    EventHandler(event: event, client: bot.client).handle()
}
