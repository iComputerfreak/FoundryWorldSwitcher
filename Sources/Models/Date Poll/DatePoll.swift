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
    var campaignRoleID: RoleSnowflake
    var requiredVoterIDs: Set<UserSnowflake>
    let createdAt: Date
    var deadline: Date
    var deadlineDuration: TimeInterval?
    var description: String?
    var candidates: [DatePollCandidate]
    var status: DatePollStatus
    var finalizedCandidateID: UUID?
    var finalizedCandidateIDs: Set<UUID>?
    var bookedFinalizedCandidateIDs: Set<UUID>?
    var finalizedCandidateBookingIDs: [UUID: UUID]?
    var finalizedBy: UserSnowflake?
    var finalizedAt: Date?
    var votes: [UserSnowflake: DatePollVote]
    var reminders: [UserSnowflake: DatePollReminderState]
    var messageSyncEventID: UUID?
    var closeEventID: UUID?
    var automaticReminderEventID: UUID?
    var automaticReminderDueDate: Date?
    var automaticReminderDeliveredUserIDs: Set<UserSnowflake>?
    var repeatIntervalWeeks: Int?
    var repeatSeriesID: String?
    var repeatEventID: UUID?
    var repeatEventCompleted: Bool?
    var repeatSourceEventID: UUID?

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
        self.deadlineDuration = deadline.timeIntervalSince(createdAt)
        self.description = description
        self.candidates = candidateDates.map(DatePollCandidate.init(date:))
        self.status = .open
        self.finalizedCandidateID = nil
        self.finalizedCandidateIDs = nil
        self.bookedFinalizedCandidateIDs = []
        self.finalizedCandidateBookingIDs = [:]
        self.finalizedBy = nil
        self.finalizedAt = nil
        self.votes = [:]
        self.reminders = [:]
        self.messageSyncEventID = nil
        self.closeEventID = nil
        self.automaticReminderEventID = nil
        self.automaticReminderDueDate = nil
        self.automaticReminderDeliveredUserIDs = []
        self.repeatIntervalWeeks = repeatIntervalWeeks
        self.repeatSeriesID = repeatIntervalWeeks == nil ? nil : id
        self.repeatEventID = nil
        self.repeatEventCompleted = false
        self.repeatSourceEventID = nil
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

    var finalizedCandidates: [DatePollCandidate] {
        let candidateIDs = finalizedCandidateIDs ?? Set([finalizedCandidateID].compactMap { $0 })
        return candidates.filter { candidateIDs.contains($0.id) }
    }
}
