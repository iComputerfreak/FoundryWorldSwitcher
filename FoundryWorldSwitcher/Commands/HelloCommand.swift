//
//  HelloCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM
import Foundation

struct HelloCommand: DiscordCommand {
    let name = "hello"
    let description = "Returns a simple message to show that the bot is working."
    let options: [ApplicationCommand.Option]? = nil
    
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws {
        try await client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: Payloads.EditWebhookMessage(
                content: "Hello, You wanted me to echo something!",
                embeds: [Embed(
                    title: "This is an embed",
                    description: """
                        You sent this, so I'll echo it to you!
                        
                        > \(DiscordUtils.escapingSpecialCharacters("echo"))
                        """,
                    timestamp: Date(),
                    color: .init(value: .random(in: 0 ..< (1 << 24) )),
                    footer: .init(text: "Footer!"),
                    author: .init(name: "Authored by DiscordBM!"),
                    fields: [
                        .init(name: "field name!", value: "field value!")
                    ]
                )],
                components: [[.button(.init(
                    label: "Open DiscordBM!",
                    url: "https://github.com/DiscordBM/DiscordBM"
                ))]]
            )
        ).guardSuccess()
        
        
        /// Edits the interaction response.
        /// This response is intentionally too fancy just so you see what's possible :)
        try await client.updateOriginalInteractionResponse(
            token: interaction.token,
            payload: Payloads.EditWebhookMessage(
                content: "Hello, You wanted me to echo something!",
                embeds: [Embed(
                    title: "This is an embed",
                    description: """
                            You sent this, so I'll echo it to you!
                            
                            > \(DiscordUtils.escapingSpecialCharacters(""))
                            """,
                    timestamp: Date(),
                    color: .init(value: .random(in: 0 ..< (1 << 24) )),
                    footer: .init(text: "Footer!"),
                    author: .init(name: "Authored by DiscordBM!"),
                    fields: [
                        .init(name: "field name!", value: "field value!")
                    ]
                )],
                components: [[.button(.init(
                    label: "Open DiscordBM!",
                    url: "https://github.com/DiscordBM/DiscordBM"
                ))]]
            )
        ).guardSuccess()
    }
}
