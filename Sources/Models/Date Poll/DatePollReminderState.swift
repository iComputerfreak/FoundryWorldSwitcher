//
//  DatePollReminderState.swift
//

import Foundation

enum DatePollReminderState: Codable, Hashable {
    case pending(eventID: UUID, dueDate: Date)
    case delivered
    case delayed(eventID: UUID, dueDate: Date)
    case delayedDelivered

    var scheduledEventID: UUID? {
        switch self {
        case let .pending(eventID, _), let .delayed(eventID, _):
            return eventID
        case .delivered, .delayedDelivered:
            return nil
        }
    }

    var scheduledDueDate: Date? {
        switch self {
        case let .pending(_, dueDate), let .delayed(_, dueDate):
            return dueDate
        case .delivered, .delayedDelivered:
            return nil
        }
    }
}
