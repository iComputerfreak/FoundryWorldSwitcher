//
//  DiscordCommandError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

enum DiscordCommandError: Error {
    case unknownCommand(commandName: String)
    case missingArgument(argumentName: String)
}
