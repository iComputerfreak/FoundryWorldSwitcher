//
//  DiscordCommand.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM
import Logging

protocol DiscordCommand {
    var name: String { get }
    var description: String { get }
    var options: [ApplicationCommand.Option]? { get }
    var logger: Logger { get }
    
    func createApplicationCommand() -> Payloads.ApplicationCommandCreate
    func handle(
        _ applicationCommand: Interaction.ApplicationCommand,
        interaction: Interaction,
        client: any DiscordClient
    ) async throws
}

extension DiscordCommand {
    var options: [ApplicationCommand.Option]? {
        nil
    }
    
    var logger: Logger {
        Logger(label: "\(String(describing: Self.self))")
    }
    
    func createApplicationCommand() -> Payloads.ApplicationCommandCreate {
        Payloads.ApplicationCommandCreate(
            name: self.name,
            description: self.description,
            options: self.options
        )
    }
}




//            return [ApplicationCommand.Option(
//                type: .string,
//                name: "text",
//                description: "What to echo :)"
//            )]
//        case .link:
//            return LinkSubCommand.allCases.map { subCommand in
//                return ApplicationCommand.Option(
//                    type: .subCommand,
//                    name: subCommand.rawValue,
//                    description: subCommand.description,
//                    options: subCommand.options
//                )
//            }
