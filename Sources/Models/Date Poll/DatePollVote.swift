//
//  DatePollVote.swift
//

import Foundation

struct DatePollVote: Codable, Hashable {
    let candidateIDs: Set<UUID>

    static let unavailable = Self(candidateIDs: [])
}
