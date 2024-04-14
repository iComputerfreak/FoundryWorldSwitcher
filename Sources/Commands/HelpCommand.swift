//
//  HelpCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import Foundation
import DiscordBM
import Logging

struct HelpCommand: DiscordCommand {
    var logger: Logger = .init(label: String(describing: Self.self))
    let name = "help"
    let description = "Displays information about the use of this bot"
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: DiscordClient
    ) async throws {
        try await client.respond(
            token: interaction.token,
            // TODO: Update
            message: """
            You can use this bot to view information about the FoundryVTT server and manage the currently running world.
            
            - Use `/worldinfo` to show the currently running world
            - Use `/listworlds` to list all worlds and their IDs.
            - Use `/switchworld <world_id>` to change the active world
            
            - Use `/book event <world_id> <date> <time> <location> <topic> <role>` to create a booking for a new session. Your players and you will be reminded about the session and the world will be locked on the day of your session.
            - Use `/book reservation <world_id> <date>` to create a new booking to prepare for a session. You will not receive a notification, but the world will be locked on the day of your booking.
            """
        )
    }
}
