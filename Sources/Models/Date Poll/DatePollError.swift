//
//  DatePollError.swift
//

import Foundation

enum DatePollError: LocalizedError {
    case notFound(String)
    case unavailablePoll
    case unauthorizedVoter
    case invalidCandidates
    case reminderUnavailable
    case reminderAlreadyScheduled
    case reminderCannotBeDelayed
    case invalidFinalizedDate
    case unauthorizedFinalization
    case missingMessageReference

    var errorDescription: String? {
        switch self {
        case let .notFound(id): return "No date poll with ID `\(id)` exists."
        case .unavailablePoll: return "This date poll is no longer open for voting."
        case .unauthorizedVoter: return "Only members of this poll's campaign role can vote."
        case .invalidCandidates: return "The selected dates are not valid for this poll."
        case .reminderUnavailable: return "A reminder would be sent after this poll expires."
        case .reminderAlreadyScheduled: return "You already requested a reminder for this poll."
        case .reminderCannotBeDelayed: return "This reminder cannot be delayed."
        case .invalidFinalizedDate: return "The selected date is not part of this poll."
        case .unauthorizedFinalization: return "Only the poll owner or an admin can finalize this poll."
        case .missingMessageReference: return "This date poll has no Discord message reference."
        }
    }
}
