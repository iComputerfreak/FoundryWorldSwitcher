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
        switch kind {
        case .reservation:
            guard Set(values.keys) == Set([Self.worldComponentID, Self.dateID]),
                  case let .stringSelect(worldSelect) = values[Self.worldComponentID],
                  let worldValues = worldSelect.values,
                  worldValues.count == 1,
                  worldValues[0] != Self.noFoundryWorldValue,
                  case let .textInput(dateInput) = values[Self.dateID], let dateValue = dateInput.value else {
                throw DiscordCommandError.missingBookingWorld
            }
            worldID = worldValues[0]
            date = try Self.parseDate(dateValue)
            campaignRoleID = nil
            locationID = nil
            topic = nil

        case .event:
            let requiredIDs: Set = [Self.dateTimeID, Self.roleID, Self.topicID]
            let allowedIDs = requiredIDs.union([Self.worldComponentID, Self.locationID])
            let receivedIDs = Set(values.keys)
            guard requiredIDs.isSubset(of: receivedIDs), receivedIDs.isSubset(of: allowedIDs) else {
                throw DiscordCommandError.invalidBookingForm
            }
            guard case let .textInput(dateTimeInput) = values[Self.dateTimeID], let dateTimeValue = dateTimeInput.value,
                  case let .roleSelect(roleSelect) = values[Self.roleID],
                  case let .textInput(topicInput) = values[Self.topicID], let topicValue = topicInput.value else {
                throw DiscordCommandError.invalidBookingForm
            }
            let roleValues = roleSelect.values ?? []
            guard roleValues.count == 1 else { throw DiscordCommandError.missingBookingRole }
            let worldValues: [String]
            if let worldComponent = values[Self.worldComponentID] {
                guard case let .stringSelect(worldSelect) = worldComponent else {
                    throw DiscordCommandError.invalidBookingForm
                }
                worldValues = worldSelect.values ?? []
            } else {
                worldValues = []
            }
            guard worldValues.count <= 1 else { throw DiscordCommandError.invalidBookingForm }
            let locationValues: [String]
            if let locationComponent = values[Self.locationID] {
                guard case let .channelSelect(locationSelect) = locationComponent else {
                    throw DiscordCommandError.invalidBookingForm
                }
                locationValues = locationSelect.values ?? []
            } else {
                locationValues = []
            }
            guard locationValues.count <= 1 else { throw DiscordCommandError.invalidBookingForm }
            worldID = worldValues.first == Self.noFoundryWorldValue ? nil : worldValues.first
            date = try Self.parseDateTime(dateTimeValue, defaultEventBookingTime: defaultEventBookingTime)
            campaignRoleID = .init(roleValues[0])
            locationID = locationValues.first.map(ChannelSnowflake.init)
            let trimmedTopic = topicValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTopic.isEmpty else { throw DiscordCommandError.missingBookingTopic }
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
            date = Utils.date(on: dateOnly, at: defaultEventBookingTime)
        } else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM.YYYY [HH:MM]")
        }
        guard date > .now else {
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
