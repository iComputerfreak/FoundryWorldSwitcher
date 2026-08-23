import DiscordBM
import Foundation

struct BookingCreationForm {
    enum Kind: String {
        case reservation
        case event
    }

    static let modalPrefix = "booking:"
    static let worldComponentID = "booking:world"
    static let dateID = "booking:date"
    static let dateTimeID = "booking:date-time"
    static let roleID = "booking:role"
    static let locationID = "booking:location"
    static let topicID = "booking:topic"
    static let noFoundryWorldValue = "no-foundry-world"

    let kind: Kind
    let worldID: String?
    let date: Date
    let campaignRoleID: RoleSnowflake?
    let locationID: ChannelSnowflake?
    let topic: String?
    let sourcePollID: String?
    let sourceCandidateID: UUID?

    init(from modal: Interaction.ModalSubmit, defaultEventBookingTime: TimeInterval) throws {
        guard let context = Self.modalContext(from: modal.custom_id), let components = modal.componentsV2 else {
            throw DiscordCommandError.invalidBookingForm
        }
        var values: [String: Interaction.ActionRow.Component] = [:]
        for component in components {
            guard case let .label(label) = component, let customID = label.component.customId, values[customID] == nil else {
                throw DiscordCommandError.invalidBookingForm
            }
            values[customID] = label.component
        }

        kind = context.kind
        sourcePollID = context.pollID
        sourceCandidateID = context.candidateID
        guard case let .stringSelect(worldSelect) = values[Self.worldComponentID], let worldValues = worldSelect.values, worldValues.count == 1 else {
            throw DiscordCommandError.invalidBookingForm
        }
        worldID = worldValues[0] == Self.noFoundryWorldValue ? nil : worldValues[0]

        switch kind {
        case .reservation:
            guard Set(values.keys) == Set([Self.worldComponentID, Self.dateID]),
                  worldID != nil,
                  case let .textInput(dateInput) = values[Self.dateID], let dateValue = dateInput.value else {
                throw DiscordCommandError.invalidBookingForm
            }
            date = try Self.parseDate(dateValue)
            campaignRoleID = nil
            locationID = nil
            topic = nil

        case .event:
            guard Set(values.keys) == Set([Self.worldComponentID, Self.dateTimeID, Self.roleID, Self.locationID, Self.topicID]),
                  case let .textInput(dateTimeInput) = values[Self.dateTimeID], let dateTimeValue = dateTimeInput.value,
                  case let .roleSelect(roleSelect) = values[Self.roleID], let roleValues = roleSelect.values, roleValues.count == 1,
                  case let .channelSelect(locationSelect) = values[Self.locationID],
                  case let .textInput(topicInput) = values[Self.topicID], let topicValue = topicInput.value else {
                throw DiscordCommandError.invalidBookingForm
            }
            let locationValues = locationSelect.values ?? []
            guard locationValues.count <= 1 else { throw DiscordCommandError.invalidBookingForm }
            date = try Self.parseDateTime(dateTimeValue, defaultEventBookingTime: defaultEventBookingTime)
            campaignRoleID = .init(roleValues[0])
            locationID = locationValues.first.map(ChannelSnowflake.init)
            let trimmedTopic = topicValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTopic.isEmpty else { throw DiscordCommandError.invalidBookingForm }
            topic = trimmedTopic
        }
    }

    static func kind(from customID: String) -> Kind? {
        modalContext(from: customID)?.kind
    }

    static func modalContext(from customID: String) -> (kind: Kind, pollID: String?, candidateID: UUID?)? {
        let parts = customID.split(separator: ":")
        guard parts.count == 2 || parts.count == 4, parts.first == "booking", let kind = Kind(rawValue: String(parts[1])) else {
            return nil
        }
        if parts.count == 2 {
            return (kind, nil, nil)
        }
        guard let candidateID = UUID(uuidString: String(parts[3])) else { return nil }
        return (kind, String(parts[2]), candidateID)
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

    private static func parseDateTime(_ value: String, defaultEventBookingTime: TimeInterval) throws -> Date {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let date: Date
        if let explicitDateTime = dateTimeFormatter.date(from: trimmedValue) {
            date = explicitDateTime
        } else if let dateOnly = dateFormatter.date(from: trimmedValue) {
            date = Calendar.current.startOfDay(for: dateOnly).addingTimeInterval(defaultEventBookingTime)
        } else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM.YYYY [HH:MM]")
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
