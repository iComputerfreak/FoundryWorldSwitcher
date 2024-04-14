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
    var permissionsLevel: BotPermissionLevel { get }
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
    
    func createApplicationCommand() -> Payloads.ApplicationCommandCreate {
        Payloads.ApplicationCommandCreate(
            name: self.name,
            description: self.description,
            options: self.options
        )
    }
    
    /// Tries to parse and return a `FoundryWorld` from the given command's arguments.
    /// - Throws: ``DiscordCommandError.missingArgument`` if the argument is missing or empty
    func parseWorld(
        from command: Interaction.ApplicationCommand,
        optionName: String
    ) async throws -> FoundryWorld {
        let option = command.option(named: optionName)
        return try await parseWorld(fromOption: option, optionName: optionName)
    }
    
    /// Tries to parse and return a `FoundryWorld` from the given subcommand's arguments.
    /// - Throws: ``DiscordCommandError.missingArgument`` if the argument is missing or empty
    func parseWorld(
        from subcommand: Interaction.ApplicationCommand.Option,
        optionName: String
    ) async throws -> FoundryWorld {
        let option = subcommand.option(named: optionName)
        return try await parseWorld(fromOption: option, optionName: optionName)
    }
    
    /// Tries to parse and return an optional `FoundryWorld` from the given command's arguments.
    func parseOptionalWorld(
        from command: Interaction.ApplicationCommand,
        optionName: String
    ) async throws -> FoundryWorld? {
        guard let option = command.option(named: optionName) else {
            return nil
        }
        return try await parseWorld(fromOption: option, optionName: optionName)
    }
    
    /// Tries to parse and return an optional `FoundryWorld` from the given command's arguments.
    func parseOptionalWorld(
        from subcommand: Interaction.ApplicationCommand.Option,
        optionName: String
    ) async throws -> FoundryWorld? {
        guard let option = subcommand.option(named: optionName) else {
            return nil
        }
        return try await parseWorld(fromOption: option, optionName: optionName)
    }
    
    private func parseWorld(
        fromOption option: Interaction.ApplicationCommand.Option?,
        optionName: String
    ) async throws -> FoundryWorld {
        guard
            let worldID = try option?.requireString(),
            !worldID.isEmpty
        else {
            throw DiscordCommandError.missingArgument(argumentName: optionName)
        }
        
        let allWorlds = try await PterodactylAPI.shared.worlds()
        guard let world = allWorlds.first(where: { $0.id == worldID }) else {
            throw DiscordCommandError.worldDoesNotExist(worldID: worldID)
        }
        
        return world
    }
}
