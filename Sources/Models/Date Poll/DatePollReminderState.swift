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
}
