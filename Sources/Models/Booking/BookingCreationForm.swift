import DiscordBM
import Foundation

struct BookingCreationForm {
    enum Kind: String {
        case reservation
        case event
    }

    static let modalPrefix = "booking:"
    static let worldID = "booking:world"
    static let dateID = "booking:date"
    static let dateTimeID = "booking:date-time"
    static let roleID = "booking:role"
    static let locationID = "booking:location"
    static let topicID = "booking:topic"

    let kind: Kind
    let worldID: String
    let date: Date
    let campaignRoleID: RoleSnowflake?
    let locationID: ChannelSnowflake?
    let topic: String?

    init(from modal: Interaction.ModalSubmit) throws {
        guard let kind = Self.kind(from: modal.custom_id), let components = modal.componentsV2 else {
            throw DiscordCommandError.invalidBookingForm
        }
        var values: [String: Interaction.ActionRow.Component] = [:]
        for component in components {
            guard case let .label(label) = component, let customID = label.component.customId, values[customID] == nil else {
                throw DiscordCommandError.invalidBookingForm
            }
            values[customID] = label.component
        }

        self.kind = kind
        guard case let .stringSelect(worldSelect) = values[Self.worldID], let worldValues = worldSelect.values, worldValues.count == 1 else {
            throw DiscordCommandError.invalidBookingForm
        }
        worldID = worldValues[0]

        switch kind {
        case .reservation:
            guard Set(values.keys) == Set([Self.worldID, Self.dateID]),
                  case let .textInput(dateInput) = values[Self.dateID], let dateValue = dateInput.value else {
                throw DiscordCommandError.invalidBookingForm
            }
            date = try Self.parseDate(dateValue)
            campaignRoleID = nil
            locationID = nil
            topic = nil

        case .event:
            guard Set(values.keys) == Set([Self.worldID, Self.dateTimeID, Self.roleID, Self.locationID, Self.topicID]),
                  case let .textInput(dateTimeInput) = values[Self.dateTimeID], let dateTimeValue = dateTimeInput.value,
                  case let .roleSelect(roleSelect) = values[Self.roleID], let roleValues = roleSelect.values, roleValues.count == 1,
                  case let .channelSelect(locationSelect) = values[Self.locationID], let locationValues = locationSelect.values, locationValues.count == 1,
                  case let .textInput(topicInput) = values[Self.topicID], let topicValue = topicInput.value else {
                throw DiscordCommandError.invalidBookingForm
            }
            date = try Self.parseDateTime(dateTimeValue)
            campaignRoleID = .init(roleValues[0])
            locationID = .init(locationValues[0])
            let trimmedTopic = topicValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTopic.isEmpty else { throw DiscordCommandError.invalidBookingForm }
            topic = trimmedTopic
        }
    }

    static func kind(from customID: String) -> Kind? {
        guard customID.hasPrefix(modalPrefix) else { return nil }
        return Kind(rawValue: String(customID.dropFirst(modalPrefix.count)))
    }

    private static func parseDate(_ value: String) throws -> Date {
        guard let date = dateFormatter.date(from: value) else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM.YYYY")
        }
        guard Calendar.current.startOfDay(for: date).addingTimeInterval(GlobalConstants.secondsPerDay) > .now else {
            throw DiscordCommandError.dateIsInThePast(date)
        }
        return date
    }

    private static func parseDateTime(_ value: String) throws -> Date {
        guard let date = dateTimeFormatter.date(from: value) else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM.YYYY HH:MM")
        }
        guard Calendar.current.startOfDay(for: date).addingTimeInterval(GlobalConstants.secondsPerDay) > .now else {
            throw DiscordCommandError.dateIsInThePast(date)
        }
        return date
    }

    private static let dateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static let dateTimeFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}
