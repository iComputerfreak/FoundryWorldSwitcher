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

// The current version printed to the console on start
let version: String = "1.7.0"

private let logger = Logger(label: "Main")

logger.info("Started bot v\(version) with data path \(Utils.dataURL.path)")

if BotConfig.shared.pterodactylHost.isEmpty {
    logger.error("The Pterodactyl host is not set. Please set it in the config file.")
}
if BotConfig.shared.pterodactylServerID.isEmpty {
    logger.error("The Pterodactyl server ID is not set. Please set it in the config file.")
}

// MARK: -  Register services
private let scheduler = Scheduler.shared
let bookingsService = BookingsService(scheduler: scheduler)

// MARK: - Set up the bot

private let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

let bot = await BotGatewayManager(
    eventLoopGroup: httpClient.eventLoopGroup,
    httpClient: httpClient,
    token: Secrets.shared.botToken,
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
    
    // Make sure the bot only runs in a single guild
    guard try await bot.client.listOwnGuilds().decode().count <= 1 else {
        await bot.disconnect()
        logger.critical(
            "The bot is in more than one guild. This bot is designed to only work in one guild. Please remove the bot from all guilds except the one you want it to work in."
        )
        fatalError(
            "The bot is in more than one guild. This bot is designed to only work in one guild. Please remove the bot from all guilds except the one you want it to work in."
        )
    }
    
    // Give the bot owner admin permissions
    do {
        let botApplication = try await bot.client.getOwnApplication().decode()
        guard let ownerID = botApplication.owner?.id else {
            throw DiscordBotError.noUser
        }
        Permissions.shared.setUserPermissionLevel(of: ownerID, to: .admin)
    } catch {
        logger.warning("Error determining the bot owner. Will not give the bot owner admin permissions. \(error)")
    }
}

let cache = await DiscordCache(
    /// The `GatewayManager`/`bot` to cache the events from.
    gatewayManager: bot,
    /// What intents to cache their related Gateway events.
    /// This does not affect what events you receive from Discord.
    /// The intents you enter here must have been enabled in your `GatewayManager`.
    /// With `.all`, `DiscordCache` will cache all events.
    intents: [.guilds, .guildMembers],
    /// In big guilds/servers, Discord only sends your own member/presence info.
    /// You need to request the rest of the members, and `DiscordCache` can do that for you.
    /// Must have `guildMembers` and `guildPresences` intents enabled depending on what you want.
    requestAllMembers: .enabled,
    /// What messages to cache.
    messageCachingPolicy: .normal
)

let permissionsHandler = PermissionsHandler(cache: cache)

// MARK: -  Register commands
try await DiscordCommands.register(bot: bot)

// MARK: - Start the bot
/// Handle each event in the `bot.events` async stream
/// This stream will never end, therefore preventing your executable from exiting
for await event in await bot.events {
    #if DEBUG
    if event.opcode == .heartbeatAccepted {
        print("Heartbeat at \(Date().formatted(date: .omitted, time: .standard))")
    }
    #endif
    EventHandler(event: event, client: bot.client, permissionsHandler: permissionsHandler).handle()
    // We receive heartbeats every ~45 seconds, so this is a good time to call the scheduler and check for
    // events to trigger
    #if DEBUG
    let schedulerPriority = TaskPriority.userInitiated
    #else
    let schedulerPriority = TaskPriority.background
    #endif
    Task(priority: schedulerPriority) {
        do {
            try await scheduler.update()
        } catch {
            logger.error("Error running scheduler: \(error.localizedDescription)\n\(error)")
        }
    }
}
