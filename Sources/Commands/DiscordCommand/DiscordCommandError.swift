//
//  DiscordCommandError.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 28.12.23.
//

import DiscordBM
import Foundation

enum DiscordCommandError: Error, LocalizedError {
    case unknownCommand(commandName: String)
    case missingArgument(argumentName: String)
    case missingSubcommand
    case noMember
    case noUser
    case noGuild
    case worldDoesNotExist(worldID: String)
    case unauthorized(requiredLevel: BotPermissionLevel)
    case wrongDateFormat(String, format: String)
    case wrongTimeFormat(String, format: String)
    case noBookingFoundAtDate(Date)
    case deleteBookingPermissionDenied(required: BotPermissionLevel)
    case bookingAlreadyExists(atDate: Date)
    case worldSwitchingIsLocked
    case forceSwitchWorldPermissionDenied(required: BotPermissionLevel)
    case noMessageID
    case dateIsInThePast(Date)
    case invalidConfigKey(String)
    case wrongDurationFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .unknownCommand(let commandName):
            return "Unknown command `\(commandName)`."
        
        case .missingArgument(let argumentName):
            return "Missing argument `\(argumentName)`."
        
        case .missingSubcommand:
            return "Missing subcommand. Please specify a sub command."
        
        case .noMember:
            return "There is no server member associated with the command."
        
        case .noUser:
            return "There is no user associated with the command."
        
        case .noGuild:
            return "There is no guild/server associated with the command."
        
        case .worldDoesNotExist(worldID: let worldID):
            return "The world `\(worldID)` does not exist."
        
        case .unauthorized(let requiredLevel):
            return "You need at least permission level `\(requiredLevel)` to execute this command."
        
        case let .wrongDateFormat(value, format: format):
            return "'\(value)' is not a valid date. Please use the format `\(format)`"
        
        case let .wrongTimeFormat(value, format: format):
            return "'\(value)' is not a valid time. Please use the format `\(format)`"
        
        case .noBookingFoundAtDate:
            return "There exists no booking at the given date."
            
        case let .deleteBookingPermissionDenied(required: required):
            return "To cancel bookings of other users, you need to have the `\(required.description)` permission level."
            
        case .bookingAlreadyExists:
            return "A booking already exists at the given date."
            
        case .worldSwitchingIsLocked:
            return "World switching is currently locked."
            
        case let .forceSwitchWorldPermissionDenied(required: required):
            return "You need to have the `\(required.description)` permission level to force a world switch."
            
        case .noMessageID:
            return "Unable to retrieve the message ID."
            
        case let .dateIsInThePast(date):
            return "The date \(Utils.outputDateFormatter.string(from: date)) is in the past."
            
        case let .invalidConfigKey(key):
            return "The config key `\(key)` does not exist."
        
        case let .wrongDurationFormat(value):
            return "'\(value)' is not a valid duration. Please use the format `1h 2m`."
        }
    }
}

extension StringIntDoubleBool.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .valueIsNotOfType(let type, let value):
            return "The value `\(value)` is not of type `\(String(describing: type))`."
        }
    }
}

extension Interaction.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .optionNotFoundInCommand(let name, let command):
            return "The option `\(name)` was not found. Please specify it."
        
        case .optionNotFoundInOption(let name, let parentOption):
            return "The option `\(name)` was not found. Please specify it."
        
        case .optionNotFoundInOptions(let name, let options):
            return "The option `\(name)` was not found. Please specify it."
        
        case .componentNotFoundInComponents(let customId, let components):
            return "The component with custom id `\(customId)` was not found in the components."
        
        case .componentNotFoundInActionRow(let customId, let actionRow):
            return "The component with custom id `\(customId)` was not found in the action row."
        
        case .componentNotFoundInActionRows(let customId, let actionRows):
            return "The component with custom id `\(customId)` was not found in the action rows."
        
        case .componentWasNotOfKind(let kind, let component):
            return "The component was not of kind `\(kind)`."
        }
    }
}
