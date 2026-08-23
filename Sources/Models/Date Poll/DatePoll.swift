//
//  DatePoll.swift
//

import DiscordBM
import Foundation

struct DatePoll: Codable, Identifiable {
    let id: String
    let ownerID: UserSnowflake
    let ownerUsername: String?
    let guildID: GuildSnowflake
    let channelID: ChannelSnowflake
    var messageID: MessageSnowflake?
    let campaignRoleID: RoleSnowflake
    var requiredVoterIDs: Set<UserSnowflake>
    let createdAt: Date
    let deadline: Date
    let description: String?
    let candidates: [DatePollCandidate]
    var status: DatePollStatus
    var finalizedCandidateID: UUID?
    var finalizedBy: UserSnowflake?
    var finalizedAt: Date?
    var votes: [UserSnowflake: DatePollVote]
    var reminders: [UserSnowflake: DatePollReminderState]
    var repeatIntervalWeeks: Int?
    var repeatSeriesID: String?
    var repeatEventID: UUID?

    init(
        id: String,
        ownerID: UserSnowflake,
        ownerUsername: String,
        guildID: GuildSnowflake,
        channelID: ChannelSnowflake,
        campaignRoleID: RoleSnowflake,
        requiredVoterIDs: Set<UserSnowflake>,
        deadline: Date,
        description: String?,
        candidateDates: [Date],
        repeatIntervalWeeks: Int?
    ) {
        self.id = id
        self.ownerID = ownerID
        self.ownerUsername = ownerUsername
        self.guildID = guildID
        self.channelID = channelID
        self.messageID = nil
        self.campaignRoleID = campaignRoleID
        self.requiredVoterIDs = requiredVoterIDs
        self.createdAt = .now
        self.deadline = deadline
        self.description = description
        self.candidates = candidateDates.map(DatePollCandidate.init(date:))
        self.status = .open
        self.finalizedCandidateID = nil
        self.finalizedBy = nil
        self.finalizedAt = nil
        self.votes = [:]
        self.reminders = [:]
        self.repeatIntervalWeeks = repeatIntervalWeeks
        self.repeatSeriesID = repeatIntervalWeeks == nil ? nil : id
        self.repeatEventID = nil
    }

    var isOpen: Bool {
        status == .open && deadline > .now
    }

    func candidate(id: UUID) -> DatePollCandidate? {
        candidates.first(where: { $0.id == id })
    }

    func candidate(on date: Date) -> DatePollCandidate? {
        let calendar = Calendar.current
        return candidates.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
    }

    func availableVoters(for candidate: DatePollCandidate) -> [UserSnowflake] {
        votes.compactMap { userID, vote in
            vote.candidateIDs.contains(candidate.id) ? userID : nil
        }
    }

    func unavailableVoters(for candidate: DatePollCandidate) -> [UserSnowflake] {
        votes.compactMap { userID, vote in
            vote.candidateIDs.contains(candidate.id) ? nil : userID
        }
    }

    var outstandingVoterIDs: [UserSnowflake] {
        requiredVoterIDs.filter { votes[$0] == nil }
    }

    var noAvailabilityVoterIDs: [UserSnowflake] {
        votes.compactMap { userID, vote in
            vote.candidateIDs.isEmpty ? userID : nil
        }
    }

    var bestCandidates: [DatePollCandidate] {
        guard !votes.isEmpty, let highestAvailability = candidates.map({ availableVoters(for: $0).count }).max() else {
            return []
        }
        return candidates.filter { availableVoters(for: $0).count == highestAvailability }
    }
}
