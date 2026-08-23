//
//  DatePollStatus.swift
//

enum DatePollStatus: String, Codable {
    case open
    case awaitingFinalization
    case finalized
    case cancelled
}
