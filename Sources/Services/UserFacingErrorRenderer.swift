//
//  UserFacingErrorRenderer.swift
//

import DiscordBM
import Foundation

/// Converts known operational errors into localized, safe user-facing messages.
enum UserFacingErrorRenderer {
    static func message(for error: any Error, localization: LocalizationContext) -> String {
        if let error = error as? DiscordCommandError {
            return message(for: error, localization: localization)
        }
        if let error = error as? DatePollError {
            return message(for: error, localization: localization)
        }
        if let error = error as? DurationParserError {
            return message(for: error, localization: localization)
        }
        if let error = error as? StringIntDoubleBool.Error {
            return message(for: error, localization: localization)
        }
        if let error = error as? Interaction.Error {
            return message(for: error, localization: localization)
        }
        return genericMessage(localization: localization)
    }

    private static func message(for error: DiscordCommandError, localization: LocalizationContext) -> String {
        switch error {
        case let .unknownCommand(commandName):
            return string("command.unknown", commandName, localization: localization)
        case let .missingArgument(argumentName):
            return string("command.argument_missing", argumentName, localization: localization)
        case .missingSubcommand:
            return string("command.subcommand_missing", localization: localization)
        case .noMember:
            return string("command.member_missing", localization: localization)
        case .noUser:
            return string("command.user_missing", localization: localization)
        case .noGuild:
            return string("command.guild_missing", localization: localization)
        case let .worldDoesNotExist(worldID):
            return string("world.not_found", worldID, localization: localization)
        case let .unauthorized(requiredLevel):
            return string("permission.command_required", permissionName(requiredLevel, localization: localization), localization: localization)
        case let .wrongDateFormat(value, format):
            return string("input.date_invalid", value, format, localization: localization)
        case let .wrongTimeFormat(value, format):
            return string("input.time_invalid", value, format, localization: localization)
        case let .noBookingFoundAtDate(date):
            return string("booking.not_found", localization.formatDate(date), localization: localization)
        case let .cancelBookingPermissionDenied(required):
            return string("permission.booking_cancel_required", permissionName(required, localization: localization), localization: localization)
        case let .bookingAlreadyExists(date):
            return string("booking.already_exists", localization.formatDate(date), localization: localization)
        case .worldSwitchingIsLocked:
            return string("world.switching_locked", localization: localization)
        case let .forceSwitchWorldPermissionDenied(required):
            return string("permission.world_force_switch_required", permissionName(required, localization: localization), localization: localization)
        case .globalWorldUnlockPermissionDenied:
            return string("permission.world_unlock_owner_required", localization: localization)
        case .noMessageID:
            return string("discord.message_reference_missing", localization: localization)
        case let .dateIsInThePast(date):
            return string("input.date_in_past", localization.formatDate(date), localization: localization)
        case let .invalidConfigKey(key):
            return string("config.key_invalid", key, localization: localization)
        case let .invalidConfigValue(key, value):
            return string("config.value_invalid", value, key, localization: localization)
        case .reminderChannelNotInGuild:
            return string("config.reminder_channel_wrong_guild", localization: localization)
        case let .wrongDurationFormat(value):
            return string("input.duration_invalid", value, localization: localization)
        case .noChannel:
            return string("command.channel_missing", localization: localization)
        case let .rescheduleBookingPermissionDenied(required):
            return string("permission.booking_reschedule_required", permissionName(required, localization: localization), localization: localization)
        case .foundryFeaturesDisabled:
            return string("foundry.features_disabled", localization: localization)
        case .invalidBookingForm:
            return string("booking.form_invalid", localization: localization)
        case .missingBookingWorld:
            return string("booking.world_missing", localization: localization)
        case .noFoundryWorlds:
            return string("booking.worlds_unavailable", localization: localization)
        case .missingBookingRole:
            return string("booking.role_missing", localization: localization)
        case .missingBookingTopic:
            return string("booking.topic_missing", localization: localization)
        }
    }

    private static func message(for error: DatePollError, localization: LocalizationContext) -> String {
        switch error {
        case let .notFound(id):
            return string("date_poll.not_found", id, localization: localization)
        case .unavailablePoll:
            return string("date_poll.voting_closed", localization: localization)
        case .unauthorizedVoter:
            return string("date_poll.voter_unauthorized", localization: localization)
        case .invalidCandidates:
            return string("date_poll.candidates_invalid", localization: localization)
        case .reminderUnavailable:
            return string("date_poll.reminder_too_late", localization: localization)
        case .reminderAlreadyScheduled:
            return string("date_poll.reminder_already_scheduled", localization: localization)
        case .reminderCannotBeDelayed:
            return string("date_poll.reminder_delay_unavailable", localization: localization)
        case .invalidFinalizedDate:
            return string("date_poll.finalized_date_invalid", localization: localization)
        case .invalidFinalizationSelection:
            return string("date_poll.finalization_selection_invalid", localization: localization)
        case .invalidCreationForm:
            return string("date_poll.creation_form_invalid", localization: localization)
        case .invalidDeadlineDays:
            return string("date_poll.deadline_days_invalid", localization: localization)
        case .unauthorizedFinalization:
            return string("date_poll.management_unauthorized", localization: localization)
        case .missingMessageReference:
            return string("date_poll.message_reference_missing", localization: localization)
        }
    }

    private static func message(for error: DurationParserError, localization: LocalizationContext) -> String {
        switch error {
        case .couldNotParseHoursOrMinutes:
            return string("duration.hours_or_minutes_missing", localization: localization)
        case .wrongFormat:
            return string("duration.format_invalid", localization: localization)
        }
    }

    private static func message(for error: StringIntDoubleBool.Error, localization: LocalizationContext) -> String {
        switch error {
        case let .valueIsNotOfType(type, value):
            return string("interaction.value_type_invalid", String(describing: value), String(describing: type), localization: localization)
        @unknown default:
            return genericMessage(localization: localization)
        }
    }

    private static func message(for error: Interaction.Error, localization: LocalizationContext) -> String {
        switch error {
        case let .optionNotFoundInCommand(name, _),
             let .optionNotFoundInOption(name, _),
             let .optionNotFoundInOptions(name, _):
            return string("interaction.option_missing", name, localization: localization)
        case let .componentNotFoundInComponents(customID, _),
             let .componentNotFoundInActionRow(customID, _),
             let .componentNotFoundInActionRows(customID, _):
            return string("interaction.component_missing", customID, localization: localization)
        case let .componentWasNotOfKind(kind, _):
            return string("interaction.component_kind_invalid", String(describing: kind), localization: localization)
        case let .dataWasNotOfKind(kind, _):
            return string("interaction.data_kind_invalid", String(describing: kind), localization: localization)
        @unknown default:
            return genericMessage(localization: localization)
        }
    }

    private static func permissionName(_ level: BotPermissionLevel, localization: LocalizationContext) -> String {
        switch level {
        case .user: return string("permission.level.user", localization: localization)
        case .dungeonMaster: return string("permission.level.dungeon_master", localization: localization)
        case .admin: return string("permission.level.admin", localization: localization)
        }
    }

    private static func genericMessage(localization: LocalizationContext) -> String {
        string("generic.unexpected", localization: localization)
    }

    private static func string(_ key: String, _ arguments: CVarArg..., localization: LocalizationContext) -> String {
        switch arguments.count {
        case 0: return localization.string(key, table: "Errors")
        case 1: return localization.string(key, table: "Errors", arguments[0])
        case 2: return localization.string(key, table: "Errors", arguments[0], arguments[1])
        default: preconditionFailure("Error messages support at most two placeholders")
        }
    }
}
