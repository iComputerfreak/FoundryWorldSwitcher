//
//  DiscordCommands.swift
//
//
//  Created by Jonas Frey on 13.04.24.
//

import DiscordBM
import Foundation

enum DiscordCommands {
    static let commands: [DiscordCommand] = [
        HelloCommand(),
        MyPermissionsCommand(),
        SetPermissionLevel(),
        ShowPermissionsCommand(),
        ListWorldsCommand(),
        WorldInfoCommand(),
        RestartWorldCommand(),
        SwitchWorldCommand(),
        HelpCommand(),
        BookingsCommands(),
        BookCommand(),
        EventQueueCommand(),
        LockWorldCommand(),
        UnlockWorldCommand(),
        LockStateCommand(),
        CancelBookingCommand(),
        PinBookingsCommand(),
//        ConfigCommand(),
    ]
    
    static func register(bot: BotGatewayManager) async throws {
        try await bot.client
            .bulkSetApplicationCommands(payload: commands.map { $0.createApplicationCommand() } )
            .guardSuccess()
    }
}
