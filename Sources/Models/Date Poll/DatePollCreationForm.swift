//
//  DatePollCreationForm.swift
//

import DiscordBM
import Foundation

struct DatePollCreationForm {
    static let modalID = "datepoll:create:form"
    static let roleID = "datepoll:create:role"
    static let datesID = "datepoll:create:dates"
    static let descriptionID = "datepoll:create:description"
    static let deadlineDaysID = "datepoll:create:deadline-days"

    let campaignRoleID: RoleSnowflake
    let candidateDates: [Date]
    let description: String?
    let deadline: Date

    init(from modal: Interaction.ModalSubmit) throws {
        guard let components = modal.componentsV2 else { throw DatePollError.invalidCreationForm }
        var values: [String: Interaction.ActionRow.Component] = [:]

        for component in components {
            guard case let .label(label) = component, let customID = label.component.customId else {
                throw DatePollError.invalidCreationForm
            }
            guard values[customID] == nil else { throw DatePollError.invalidCreationForm }
            values[customID] = label.component
        }

        guard Set(values.keys) == Set([Self.roleID, Self.datesID, Self.descriptionID, Self.deadlineDaysID]) else {
            throw DatePollError.invalidCreationForm
        }
        guard case let .roleSelect(roleSelect) = values[Self.roleID], let roleValues = roleSelect.values, roleValues.count == 1 else {
            throw DatePollError.invalidCreationForm
        }
        guard case let .textInput(datesInput) = values[Self.datesID], let datesValue = datesInput.value else {
            throw DatePollError.invalidCreationForm
        }
        guard case let .textInput(descriptionInput) = values[Self.descriptionID] else {
            throw DatePollError.invalidCreationForm
        }
        guard case let .textInput(deadlineInput) = values[Self.deadlineDaysID], let deadlineValue = deadlineInput.value else {
            throw DatePollError.invalidCreationForm
        }

        self.campaignRoleID = .init(roleValues[0])
        self.candidateDates = try Self.parseDates(datesValue)
        let description = descriptionInput.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.description = description.isEmpty ? nil : description
        self.deadline = try Self.parseDeadline(days: deadlineValue)
    }

    private static func parseDates(_ value: String) throws -> [Date] {
        let dates = try value
            .split(whereSeparator: \.isNewline)
            .map { try parseDate(String($0).trimmingCharacters(in: .whitespaces)) }
        guard !dates.isEmpty, dates.count <= 20, Set(dates).count == dates.count else {
            throw DatePollError.invalidCandidates
        }
        guard dates.allSatisfy({ Calendar.current.startOfDay(for: $0).addingTimeInterval(GlobalConstants.secondsPerDay) > .now }) else {
            throw DiscordCommandError.dateIsInThePast(dates.first ?? .now)
        }
        return dates
    }

    private static func parseDate(_ value: String) throws -> Date {
        if let date = Utils.inputDateFormatter.date(from: value) {
            return date
        }

        let components = value
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .split(separator: ".", omittingEmptySubsequences: false)
        guard
            components.count == 2,
            let day = Int(components[0]),
            let month = Int(components[1])
        else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM or DD.MM.YYYY")
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        guard let thisYearDate = date(day: day, month: month, year: currentYear, calendar: calendar) else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM or DD.MM.YYYY")
        }
        if calendar.startOfDay(for: thisYearDate).addingTimeInterval(GlobalConstants.secondsPerDay) > .now {
            return thisYearDate
        }
        guard let nextYearDate = date(day: day, month: month, year: currentYear + 1, calendar: calendar) else {
            throw DiscordCommandError.wrongDateFormat(value, format: "DD.MM or DD.MM.YYYY")
        }
        return nextYearDate
    }

    private static func date(day: Int, month: Int, year: Int, calendar: Calendar) -> Date? {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        guard
            calendar.component(.day, from: date) == day,
            calendar.component(.month, from: date) == month,
            calendar.component(.year, from: date) == year
        else {
            return nil
        }
        return date
    }

    private static func parseDeadline(days value: String) throws -> Date {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let days = Int(trimmedValue), (1...60).contains(days) else {
            throw DatePollError.invalidDeadlineDays
        }
        return .now.addingTimeInterval(TimeInterval(days) * GlobalConstants.secondsPerDay)
    }
}
