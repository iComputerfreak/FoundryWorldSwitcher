//
//  DatePollCandidate.swift
//

import Foundation

struct DatePollCandidate: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date

    init(date: Date) {
        self.id = UUID()
        self.date = date
    }
}
