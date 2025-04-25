//
//  HelloCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM
import Foundation
import Logging

struct HelloCommand: DiscordCommand {
    let logger: Logger = .init(label: String(describing: Self.self))
    let name = "hello"
    let description = "Returns a simple message to show that the bot is working"
    let permissionsLevel: BotPermissionLevel = .user
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        try await client.respond(
            token: interaction.token,
            message: "Hello, I am listening!\n__Bot version \(version)__"
        )
    }
}
