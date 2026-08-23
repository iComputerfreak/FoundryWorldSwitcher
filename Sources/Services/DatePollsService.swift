//
//  DatePollsService.swift
//

import DiscordBM
import Foundation
import Logging

actor DatePollsService {
    private enum Constants {
        static let dataPath = Utils.dataURL.appendingPathComponent("date_polls.json")
        static let identifierLength = 8
    }

    private static let logger = Logger(label: String(describing: DatePollsService.self))

    let scheduler: Scheduler
    private var polls: [DatePoll]

    init(scheduler: Scheduler) {
        self.scheduler = scheduler
        self.polls = Self.loadPolls()
    }

    func createPoll(
        ownerID: UserSnowflake,
        ownerUsername: String,
        guildID: GuildSnowflake,
        channelID: ChannelSnowflake,
        campaignRoleID: RoleSnowflake,
        requiredVoterIDs: Set<UserSnowflake>,
        deadline: Date,
        description: String?,
        candidateDates: [Date]
    ) -> DatePoll {
        let poll = DatePoll(
            id: nextIdentifier(),
            ownerID: ownerID,
            ownerUsername: ownerUsername,
            guildID: guildID,
            channelID: channelID,
            campaignRoleID: campaignRoleID,
            requiredVoterIDs: requiredVoterIDs,
            deadline: deadline,
            description: description,
            candidateDates: candidateDates
        )
        polls.append(poll)
        savePolls()
        return poll
    }

    func publishPoll(id: String, messageID: MessageSnowflake) async throws {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        polls[index].messageID = messageID
        savePolls()
        await scheduler.schedule(.init(dueDate: polls[index].deadline, eventType: .closeDatePoll(pollID: id)))
    }

    func poll(id: String) throws -> DatePoll {
        guard let poll = polls.first(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        return poll
    }

    func vote(
        pollID: String,
        voterID: UserSnowflake,
        candidateIDs: Set<UUID>,
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> DatePoll {
        let index = try votePollIndex(
            pollID: pollID,
            voterID: voterID,
            guildID: guildID,
            channelID: channelID,
            messageID: messageID
        )
        let validCandidateIDs = Set(polls[index].candidates.map(\.id))
        guard candidateIDs.isSubset(of: validCandidateIDs) else {
            throw DatePollError.invalidCandidates
        }
        polls[index].votes[voterID] = DatePollVote(candidateIDs: candidateIDs)
        savePolls()
        return polls[index]
    }

    func pollForVoteModal(
        pollID: String,
        voterID: UserSnowflake,
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> DatePoll {
        polls[try votePollIndex(
            pollID: pollID,
            voterID: voterID,
            guildID: guildID,
            channelID: channelID,
            messageID: messageID
        )]
    }

    func requestReminder(pollID: String, voterID: UserSnowflake) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == pollID }) else {
            throw DatePollError.notFound(pollID)
        }
        guard polls[index].isOpen else { throw DatePollError.unavailablePoll }
        guard polls[index].requiredVoterIDs.contains(voterID) else {
            throw DatePollError.unauthorizedVoter
        }
        guard polls[index].deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) else {
            throw DatePollError.reminderUnavailable
        }
        guard polls[index].reminders[voterID] == nil else {
            throw DatePollError.reminderAlreadyScheduled
        }

        let event = SchedulerEvent(
            dueDate: .now.addingTimeInterval(GlobalConstants.secondsPerDay),
            eventType: .sendDatePollReminder(pollID: pollID, userID: voterID)
        )
        polls[index].reminders[voterID] = .pending(eventID: event.id, dueDate: event.dueDate)
        savePolls()
        await scheduler.schedule(event)
        return polls[index]
    }

    func reminderPoll(pollID: String, userID: UserSnowflake) throws -> DatePoll? {
        guard let poll = polls.first(where: { $0.id == pollID }), poll.isOpen else { return nil }
        switch poll.reminders[userID] {
        case .pending(_, _), .delayed(_, _):
            return poll
        case .delivered, .delayedDelivered, nil:
            return nil
        }
    }

    func markReminderDelivered(pollID: String, userID: UserSnowflake) {
        guard let index = polls.firstIndex(where: { $0.id == pollID }) else { return }
        switch polls[index].reminders[userID] {
        case .pending(_, _):
            polls[index].reminders[userID] = .delivered
        case .delayed(_, _):
            polls[index].reminders[userID] = .delayedDelivered
        case .delivered, .delayedDelivered, nil:
            return
        }
        savePolls()
    }

    func delayReminder(pollID: String, userID: UserSnowflake) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == pollID }) else {
            throw DatePollError.notFound(pollID)
        }
        guard polls[index].isOpen else { throw DatePollError.unavailablePoll }
        guard let reminder = polls[index].reminders[userID], case .delivered = reminder else {
            throw DatePollError.reminderCannotBeDelayed
        }
        guard polls[index].deadline > .now.addingTimeInterval(GlobalConstants.secondsPerDay) else {
            throw DatePollError.reminderUnavailable
        }

        let event = SchedulerEvent(
            dueDate: .now.addingTimeInterval(GlobalConstants.secondsPerDay),
            eventType: .sendDatePollReminder(pollID: pollID, userID: userID)
        )
        polls[index].reminders[userID] = .delayed(eventID: event.id, dueDate: event.dueDate)
        savePolls()
        await scheduler.schedule(event)
        return polls[index]
    }

    func closePoll(id: String) async throws -> DatePoll? {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        guard polls[index].status == .open else { return nil }
        polls[index].status = .awaitingFinalization
        let reminderEvents = polls[index].reminders.values.compactMap(\.scheduledEventID)
        polls[index].reminders.removeAll()
        savePolls()
        await scheduler.unqueue(ids: reminderEvents)
        return polls[index]
    }

    func finalizePoll(id: String, date: Date, userID: UserSnowflake, roles: [RoleSnowflake]) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        guard polls[index].ownerID == userID || Permissions.shared.permissionsLevel(of: userID, roles: roles) == .admin else {
            throw DatePollError.unauthorizedFinalization
        }
        guard let candidate = polls[index].candidate(on: date) else {
            throw DatePollError.invalidFinalizedDate
        }
        guard polls[index].status == .open || polls[index].status == .awaitingFinalization else {
            throw DatePollError.unavailablePoll
        }
        polls[index].status = .finalized
        polls[index].finalizedCandidateID = candidate.id
        polls[index].finalizedBy = userID
        polls[index].finalizedAt = .now
        let reminderEvents = polls[index].reminders.values.compactMap(\.scheduledEventID)
        polls[index].reminders.removeAll()
        savePolls()
        await scheduler.unqueue(ids: reminderEvents)
        return polls[index]
    }

    func cancelPoll(id: String, userID: UserSnowflake, roles: [RoleSnowflake]) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        guard polls[index].ownerID == userID || Permissions.shared.permissionsLevel(of: userID, roles: roles) == .admin else {
            throw DatePollError.unauthorizedFinalization
        }
        guard polls[index].status == .open || polls[index].status == .awaitingFinalization else {
            throw DatePollError.unavailablePoll
        }
        polls[index].status = .cancelled
        let reminderEvents = polls[index].reminders.values.compactMap(\.scheduledEventID)
        polls[index].reminders.removeAll()
        savePolls()
        await scheduler.unqueue(ids: reminderEvents)
        return polls[index]
    }

    private func nextIdentifier() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var identifier: String
        repeat {
            identifier = String((0..<Constants.identifierLength).map { _ in alphabet.randomElement()! })
        } while polls.contains(where: { $0.id == identifier })
        return identifier
    }

    private func votePollIndex(
        pollID: String,
        voterID: UserSnowflake,
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> Int {
        guard let index = polls.firstIndex(where: { $0.id == pollID }) else {
            throw DatePollError.notFound(pollID)
        }
        guard polls[index].isOpen else { throw DatePollError.unavailablePoll }
        guard polls[index].guildID == guildID, polls[index].channelID == channelID, polls[index].messageID == messageID else {
            throw DatePollError.notFound(pollID)
        }
        guard polls[index].requiredVoterIDs.contains(voterID) else {
            throw DatePollError.unauthorizedVoter
        }
        return index
    }

    private func savePolls() {
        do {
            let data = try JSONEncoder().encode(polls)
            try data.write(to: Constants.dataPath)
        } catch {
            Self.logger.error("Failed to save date polls: \(error)")
        }
    }

    private static func loadPolls() -> [DatePoll] {
        guard FileManager.default.fileExists(atPath: Constants.dataPath.path) else { return [] }
        do {
            return try JSONDecoder().decode([DatePoll].self, from: Data(contentsOf: Constants.dataPath))
        } catch {
            logger.error("Failed to load date polls: \(error)")
            return []
        }
    }
}
