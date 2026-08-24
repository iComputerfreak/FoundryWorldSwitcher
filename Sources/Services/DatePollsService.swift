//
//  DatePollsService.swift
//

import DiscordBM
import Foundation
import Logging

actor DatePollsService {
    private enum Constants {
        static let identifierLength = 8
    }

    private static let logger = Logger(label: String(describing: DatePollsService.self))

    let scheduler: Scheduler
    let dataPath: URL
    let permissions: Permissions
    private var polls: [DatePoll]

    init(
        scheduler: Scheduler,
        dataPath: URL,
        permissions: Permissions
    ) throws {
        self.scheduler = scheduler
        self.dataPath = dataPath
        self.permissions = permissions
        self.polls = try Self.loadPolls(from: dataPath)
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
        candidateDates: [Date],
        repeatIntervalWeeks: Int?
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
            candidateDates: candidateDates,
            repeatIntervalWeeks: repeatIntervalWeeks
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
        if let sourceEventID = polls[index].repeatSourceEventID,
           let sourceIndex = polls.firstIndex(where: { $0.repeatEventID == sourceEventID }) {
            polls[sourceIndex].repeatEventCompleted = true
        }
        let events = schedulingEvents(for: index)
        savePolls()
        await scheduler.scheduleIfMissing(events)
    }

    func discardUnpublishedPoll(id: String) {
        guard let index = polls.firstIndex(where: { $0.id == id }), polls[index].messageID == nil else { return }
        polls.remove(at: index)
        savePolls()
    }

    func poll(id: String) throws -> DatePoll {
        guard let poll = polls.first(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        return poll
    }

    func publishedPolls() -> [DatePoll] {
        polls.filter { $0.messageID != nil }
    }

    func editPoll(
        id: String,
        campaignRoleID: RoleSnowflake,
        requiredVoterIDs: Set<UserSnowflake>,
        candidateDates: [Date],
        description: String?,
        deadline: Date,
        repeatIntervalWeeks: Int?,
        userID: UserSnowflake,
        roles: [RoleSnowflake]
    ) async throws -> [DatePoll] {
        guard let sourceIndex = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        try authorizeManagement(of: polls[sourceIndex], userID: userID, roles: roles)
        guard polls[sourceIndex].status == .open || polls[sourceIndex].status == .awaitingFinalization else {
            throw DatePollError.unavailablePoll
        }

        let source = polls[sourceIndex]
        let seriesID = source.repeatSeriesID
        let indices = polls.indices.filter {
            ($0 == sourceIndex || (seriesID != nil && polls[$0].repeatSeriesID == seriesID)) &&
                (polls[$0].status == .open || polls[$0].status == .awaitingFinalization)
        }
        let calendar = Calendar.current
        let deadlineDuration = deadline.timeIntervalSince(.now)
        var removedReminderEventIDs: [UUID] = []
        var removedMessageSyncEventIDs: [UUID] = []
        var events: [SchedulerEvent] = []

        for index in indices {
            let offsetDays = calendar.dateComponents(
                [.day],
                from: source.candidates[0].date,
                to: polls[index].candidates[0].date
            ).day ?? 0
            let occurrenceDates = candidateDates.compactMap {
                calendar.date(byAdding: .day, value: offsetDays, to: $0)
            }
            guard occurrenceDates.count == candidateDates.count else {
                throw DatePollError.invalidCandidates
            }

            let existingCandidates = Dictionary(uniqueKeysWithValues: polls[index].candidates.map { ($0.date, $0) })
            polls[index].campaignRoleID = campaignRoleID
            polls[index].requiredVoterIDs = requiredVoterIDs
            polls[index].candidates = occurrenceDates.map { existingCandidates[$0] ?? .init(date: $0) }
            polls[index].description = description
            polls[index].deadline = deadline
            polls[index].deadlineDuration = deadlineDuration
            polls[index].status = .open
            polls[index].repeatIntervalWeeks = repeatIntervalWeeks
            if repeatIntervalWeeks != nil {
                polls[index].repeatSeriesID = source.repeatSeriesID ?? source.id
            }
            polls[index].repeatEventID = nil
            polls[index].repeatEventCompleted = false
            removedMessageSyncEventIDs += [polls[index].messageSyncEventID].compactMap { $0 }

            let validCandidateIDs = Set(polls[index].candidates.map(\.id))
            polls[index].votes = polls[index].votes
                .filter { requiredVoterIDs.contains($0.key) }
                .mapValues { .init(candidateIDs: $0.candidateIDs.intersection(validCandidateIDs)) }

            let retainedReminders = polls[index].reminders.filter { voterID, reminder in
                guard requiredVoterIDs.contains(voterID) else { return false }
                guard let dueDate = reminder.scheduledDueDate else { return true }
                return dueDate < deadline
            }
            removedReminderEventIDs += polls[index].reminders
                .filter { retainedReminders[$0.key] == nil }
                .compactMap { $0.value.scheduledEventID }
            polls[index].reminders = retainedReminders

            let closeEvent = SchedulerEvent(dueDate: deadline, eventType: .closeDatePoll(pollID: polls[index].id))
            polls[index].closeEventID = closeEvent.id
            events.append(closeEvent)
            if let repeatIntervalWeeks,
               let repeatDate = calendar.date(byAdding: .weekOfYear, value: repeatIntervalWeeks, to: polls[index].createdAt) {
                let repeatEvent = SchedulerEvent(dueDate: repeatDate, eventType: .repeatDatePoll(pollID: polls[index].id))
                polls[index].repeatEventID = repeatEvent.id
                events.append(repeatEvent)
            }
            if let messageSyncEvent = markMessageSyncPending(for: index) {
                events.append(messageSyncEvent)
            }
        }

        savePolls()
        await scheduler.unqueueDatePollSchedulingEvents(pollIDs: Set(indices.map { polls[$0].id }))
        await scheduler.unqueue(ids: removedReminderEventIDs)
        await scheduler.unqueue(ids: removedMessageSyncEventIDs)
        await scheduler.schedule(events)
        return indices.map { polls[$0] }
    }

    func vote(
        pollID: String,
        voterID: UserSnowflake,
        candidateIDs: Set<UUID>,
        currentVoterIDs: Set<UserSnowflake>,
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) async throws -> DatePoll {
        let index = try votePollIndex(
            pollID: pollID,
            guildID: guildID,
            channelID: channelID,
            messageID: messageID
        )
        guard currentVoterIDs.contains(voterID) else { throw DatePollError.unauthorizedVoter }

        let removedVoterIDs = polls[index].requiredVoterIDs.subtracting(currentVoterIDs)
        let removedReminderEvents = removedVoterIDs.compactMap { polls[index].reminders[$0]?.scheduledEventID }
            + [polls[index].reminders[voterID]?.scheduledEventID].compactMap { $0 }
        polls[index].requiredVoterIDs = currentVoterIDs
        polls[index].votes = polls[index].votes.filter { currentVoterIDs.contains($0.key) }
        polls[index].reminders = polls[index].reminders.filter { currentVoterIDs.contains($0.key) }
        polls[index].reminders.removeValue(forKey: voterID)

        let validCandidateIDs = Set(polls[index].candidates.map(\.id))
        guard candidateIDs.isSubset(of: validCandidateIDs) else {
            throw DatePollError.invalidCandidates
        }
        polls[index].votes[voterID] = DatePollVote(candidateIDs: candidateIDs)
        savePolls()
        await scheduler.unqueue(ids: removedReminderEvents)
        return polls[index]
    }

    func pollForVoteModal(
        pollID: String,
        roles: [RoleSnowflake],
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> DatePoll {
        let index = try votePollIndex(
            pollID: pollID,
            guildID: guildID,
            channelID: channelID,
            messageID: messageID
        )
        guard roles.contains(polls[index].campaignRoleID) else {
            throw DatePollError.unauthorizedVoter
        }
        return polls[index]
    }

    func pollForManagementControl(
        pollID: String,
        userID: UserSnowflake,
        roles: [RoleSnowflake],
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == pollID }) else {
            throw DatePollError.notFound(pollID)
        }
        guard polls[index].status == .open || polls[index].status == .awaitingFinalization else {
            throw DatePollError.unavailablePoll
        }
        guard polls[index].guildID == guildID, polls[index].channelID == channelID, polls[index].messageID == messageID else {
            throw DatePollError.notFound(pollID)
        }
        try authorizeManagement(of: polls[index], userID: userID, roles: roles)
        return polls[index]
    }

    func pollForRepeatManagementControl(
        pollID: String,
        userID: UserSnowflake,
        roles: [RoleSnowflake],
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == pollID }) else {
            throw DatePollError.notFound(pollID)
        }
        guard polls[index].repeatIntervalWeeks != nil else {
            throw DatePollError.unavailablePoll
        }
        guard polls[index].guildID == guildID, polls[index].channelID == channelID, polls[index].messageID == messageID else {
            throw DatePollError.notFound(pollID)
        }
        try authorizeManagement(of: polls[index], userID: userID, roles: roles)
        return polls[index]
    }

    func pollForVotesModal(
        pollID: String,
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> DatePoll {
        guard let poll = polls.first(where: { $0.id == pollID }), poll.status == .finalized else {
            throw DatePollError.unavailablePoll
        }
        guard poll.guildID == guildID, poll.channelID == channelID, poll.messageID == messageID else {
            throw DatePollError.notFound(pollID)
        }
        return poll
    }

    func finalizedCandidateForBookingControl(
        pollID: String,
        candidateID: UUID,
        guildID: GuildSnowflake?,
        channelID: ChannelSnowflake?,
        messageID: MessageSnowflake?
    ) throws -> (poll: DatePoll, candidate: DatePollCandidate) {
        let poll = try pollForVotesModal(
            pollID: pollID,
            guildID: guildID,
            channelID: channelID,
            messageID: messageID
        )
        guard let candidate = poll.finalizedCandidates.first(where: { $0.id == candidateID }),
              !(poll.bookedFinalizedCandidateIDs ?? []).contains(candidateID) else {
            throw DatePollError.unavailablePoll
        }
        return (poll, candidate)
    }

    func claimFinalizedCandidateBooking(
        pollID: String,
        candidateID: UUID,
        bookingID: UUID,
        bookingDate: Date
    ) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == pollID }),
               polls[index].status == .finalized,
              let candidate = polls[index].finalizedCandidates.first(where: { $0.id == candidateID }),
              Calendar.current.isDate(candidate.date, inSameDayAs: bookingDate),
              !(polls[index].bookedFinalizedCandidateIDs ?? []).contains(candidateID) else {
            throw DatePollError.unavailablePoll
        }
        polls[index].bookedFinalizedCandidateIDs = (polls[index].bookedFinalizedCandidateIDs ?? []).union([candidateID])
        polls[index].finalizedCandidateBookingIDs = (polls[index].finalizedCandidateBookingIDs ?? [:]).merging(
            [candidateID: bookingID],
            uniquingKeysWith: { _, new in new }
        )
        let messageSyncEvent = markMessageSyncPending(for: index)
        savePolls()
        if let messageSyncEvent {
            await scheduler.schedule(messageSyncEvent)
        }
        return polls[index]
    }

    func releaseFinalizedCandidateBooking(pollID: String, candidateID: UUID, bookingID: UUID) async {
        guard let index = polls.firstIndex(where: { $0.id == pollID }),
              polls[index].finalizedCandidateBookingIDs?[candidateID] == bookingID else {
            return
        }
        polls[index].finalizedCandidateBookingIDs?.removeValue(forKey: candidateID)
        polls[index].bookedFinalizedCandidateIDs?.remove(candidateID)
        let messageSyncEvent = markMessageSyncPending(for: index)
        savePolls()
        if let messageSyncEvent {
            await scheduler.schedule(messageSyncEvent)
        }
    }

    /// Releases finalized candidates whose linked booking no longer occupies that candidate date.
    func reconcileBookingLinks(bookings: [any Booking]) async -> [DatePoll] {
        let calendar = Calendar.current
        var updatedPolls: [DatePoll] = []
        var messageSyncEvents: [SchedulerEvent] = []

        for index in polls.indices {
            var links = polls[index].finalizedCandidateBookingIDs ?? [:]
            let staleCandidateIDs = links.compactMap { candidateID, bookingID -> UUID? in
                guard let candidate = polls[index].candidate(id: candidateID),
                      let booking = bookings.first(where: { $0.id == bookingID }),
                      !booking.wasCancelled,
                      calendar.isDate(candidate.date, inSameDayAs: booking.date) else {
                    return candidateID
                }
                return nil
            }
            guard !staleCandidateIDs.isEmpty else { continue }

            for candidateID in staleCandidateIDs {
                links.removeValue(forKey: candidateID)
                polls[index].bookedFinalizedCandidateIDs?.remove(candidateID)
            }
            polls[index].finalizedCandidateBookingIDs = links
            if let messageSyncEvent = markMessageSyncPending(for: index) {
                messageSyncEvents.append(messageSyncEvent)
            }
            updatedPolls.append(polls[index])
        }

        guard !updatedPolls.isEmpty else { return [] }
        savePolls()
        await scheduler.schedule(messageSyncEvents)
        return updatedPolls
    }

    func repeatPollSource(pollID: String, eventID: UUID) -> DatePoll? {
        guard let poll = polls.first(where: { $0.id == pollID }), poll.repeatEventID == eventID, poll.repeatIntervalWeeks != nil else {
            return nil
        }
        return poll
    }

    func createRepeatingPoll(
        sourceID: String,
        eventID: UUID,
        scheduledDate: Date,
        requiredVoterIDs: Set<UserSnowflake>
    ) -> DatePoll? {
        guard let source = repeatPollSource(pollID: sourceID, eventID: eventID),
              let repeatIntervalWeeks = source.repeatIntervalWeeks,
              repeatIntervalWeeks > 0 else {
            return nil
        }
        if let existingPoll = polls.first(where: { $0.repeatSourceEventID == eventID }) {
            return existingPoll.messageID == nil ? existingPoll : nil
        }
        let calendar = Calendar.current
        let deadlineDuration = source.deadlineDuration ?? source.deadline.timeIntervalSince(source.createdAt)
        var occurrenceDate = scheduledDate
        var candidateDates = source.candidates.compactMap {
            calendar.date(byAdding: .weekOfYear, value: repeatIntervalWeeks, to: $0.date)
        }
        guard candidateDates.count == source.candidates.count else { return nil }
        var nextOccurrenceDate = calendar.date(byAdding: .weekOfYear, value: repeatIntervalWeeks, to: occurrenceDate)

        while occurrenceDate.addingTimeInterval(deadlineDuration) <= .now
            || candidateDates.contains(where: {
                calendar.startOfDay(for: $0).addingTimeInterval(GlobalConstants.secondsPerDay) <= .now
            })
            || (nextOccurrenceDate ?? .distantPast) <= .now {
            guard let nextDate = nextOccurrenceDate else {
                return nil
            }
            let nextCandidateDates = candidateDates.compactMap {
                calendar.date(byAdding: .weekOfYear, value: repeatIntervalWeeks, to: $0)
            }
            guard nextCandidateDates.count == candidateDates.count else { return nil }
            occurrenceDate = nextDate
            candidateDates = nextCandidateDates
            nextOccurrenceDate = calendar.date(byAdding: .weekOfYear, value: repeatIntervalWeeks, to: occurrenceDate)
        }

        var poll = DatePoll(
            id: nextIdentifier(),
            ownerID: source.ownerID,
            ownerUsername: source.ownerUsername ?? "unknown",
            guildID: source.guildID,
            channelID: source.channelID,
            campaignRoleID: source.campaignRoleID,
            requiredVoterIDs: requiredVoterIDs,
            deadline: occurrenceDate.addingTimeInterval(deadlineDuration),
            description: source.description,
            candidateDates: candidateDates,
            repeatIntervalWeeks: repeatIntervalWeeks,
            createdAt: occurrenceDate
        )
        poll.repeatSeriesID = source.repeatSeriesID ?? source.id
        poll.repeatSourceEventID = eventID
        polls.append(poll)
        savePolls()
        return poll
    }

    func requestReminder(pollID: String, voterID: UserSnowflake) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == pollID }) else {
            throw DatePollError.notFound(pollID)
        }
        guard polls[index].isOpen else { throw DatePollError.unavailablePoll }
        guard polls[index].requiredVoterIDs.contains(voterID) else {
            throw DatePollError.unauthorizedVoter
        }
        guard polls[index].votes[voterID] == nil else { throw DatePollError.reminderUnavailable }
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
        guard let poll = polls.first(where: { $0.id == pollID }), poll.isOpen, poll.votes[userID] == nil else { return nil }
        switch poll.reminders[userID] {
        case .pending(_, _), .delayed(_, _):
            return poll
        case .delivered, .delayedDelivered, nil:
            return nil
        }
    }

    func automaticReminderRecipients(
        pollID: String,
        eventID: UUID,
        currentVoterIDs: Set<UserSnowflake>,
        optedOutUserIDs: Set<UserSnowflake>
    ) async throws -> (poll: DatePoll, recipientIDs: [UserSnowflake])? {
        guard let index = polls.firstIndex(where: { $0.id == pollID }),
              polls[index].automaticReminderEventID == eventID,
              polls[index].isOpen else {
            return nil
        }

        let removedVoterIDs = polls[index].requiredVoterIDs.subtracting(currentVoterIDs)
        let removedReminderEvents = removedVoterIDs.compactMap { polls[index].reminders[$0]?.scheduledEventID }
        polls[index].requiredVoterIDs = currentVoterIDs
        polls[index].votes = polls[index].votes.filter { currentVoterIDs.contains($0.key) }
        polls[index].reminders = polls[index].reminders.filter { currentVoterIDs.contains($0.key) }
        let deliveredUserIDs = polls[index].automaticReminderDeliveredUserIDs ?? []
        let recipientIDs = Set(polls[index].outstandingVoterIDs)
            .subtracting(optedOutUserIDs)
            .subtracting(deliveredUserIDs)
        savePolls()
        await scheduler.unqueue(ids: removedReminderEvents)
        return (polls[index], Array(recipientIDs))
    }

    func markAutomaticReminderDelivered(pollID: String, eventID: UUID, userID: UserSnowflake) {
        guard let index = polls.firstIndex(where: { $0.id == pollID }), polls[index].automaticReminderEventID == eventID else {
            return
        }
        polls[index].automaticReminderDeliveredUserIDs = (polls[index].automaticReminderDeliveredUserIDs ?? []).union([userID])
        savePolls()
    }

    func completeAutomaticReminder(pollID: String, eventID: UUID) {
        guard let index = polls.firstIndex(where: { $0.id == pollID }), polls[index].automaticReminderEventID == eventID else {
            return
        }
        polls[index].automaticReminderEventID = nil
        savePolls()
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

    func closePoll(id: String, eventID: UUID) async throws -> DatePoll? {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        guard polls[index].closeEventID == eventID else { return nil }
        if polls[index].status == .open {
            polls[index].status = .awaitingFinalization
            let reminderEvents = polls[index].reminders.values.compactMap(\.scheduledEventID) + [polls[index].automaticReminderEventID].compactMap { $0 }
            polls[index].reminders.removeAll()
            polls[index].automaticReminderEventID = nil
            savePolls()
            await scheduler.unqueue(ids: reminderEvents)
        }
        guard polls[index].status == .awaitingFinalization else { return nil }
        return polls[index]
    }

    func pollForMessageSync(pollID: String, eventID: UUID) -> DatePoll? {
        guard let poll = polls.first(where: { $0.id == pollID && $0.messageSyncEventID == eventID }) else {
            return nil
        }
        return poll
    }

    func markMessageSynced(pollID: String, eventID: UUID?) {
        guard let eventID,
              let index = polls.firstIndex(where: { $0.id == pollID && $0.messageSyncEventID == eventID }) else {
            return
        }
        polls[index].messageSyncEventID = nil
        savePolls()
    }

    /// Restores missing persisted deadline, repeat, and reminder events after a restart.
    func restoreScheduling() async {
        var events: [SchedulerEvent] = []
        for index in polls.indices where polls[index].messageID != nil {
            events.append(contentsOf: schedulingEvents(for: index))
        }
        guard !events.isEmpty else { return }
        savePolls()
        await scheduler.scheduleIfMissing(events)
    }

    func finalizePoll(id: String, candidateIDs: Set<UUID>, userID: UserSnowflake, roles: [RoleSnowflake]) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        try authorizeManagement(of: polls[index], userID: userID, roles: roles)
        let validCandidateIDs = Set(polls[index].candidates.map(\.id))
        guard !candidateIDs.isEmpty, candidateIDs.isSubset(of: validCandidateIDs) else { throw DatePollError.invalidFinalizationSelection }
        guard polls[index].status == .open || polls[index].status == .awaitingFinalization else {
            throw DatePollError.unavailablePoll
        }
        polls[index].status = .finalized
        polls[index].finalizedCandidateIDs = candidateIDs
        polls[index].finalizedCandidateID = polls[index].candidates.first(where: { candidateIDs.contains($0.id) })?.id
        polls[index].finalizedBy = userID
        polls[index].finalizedAt = .now
        let reminderEvents = polls[index].reminders.values.compactMap(\.scheduledEventID) + [polls[index].automaticReminderEventID].compactMap { $0 }
        polls[index].reminders.removeAll()
        polls[index].automaticReminderEventID = nil
        let messageSyncEvent = markMessageSyncPending(for: index)
        savePolls()
        await scheduler.unqueue(ids: reminderEvents)
        if let messageSyncEvent {
            await scheduler.schedule(messageSyncEvent)
        }
        return polls[index]
    }

    func cancelPoll(id: String, userID: UserSnowflake, roles: [RoleSnowflake]) async throws -> DatePoll {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        try authorizeManagement(of: polls[index], userID: userID, roles: roles)
        guard polls[index].status == .open || polls[index].status == .awaitingFinalization else {
            throw DatePollError.unavailablePoll
        }
        polls[index].status = .cancelled
        let reminderEvents = polls[index].reminders.values.compactMap(\.scheduledEventID) + [polls[index].automaticReminderEventID].compactMap { $0 }
        polls[index].reminders.removeAll()
        polls[index].automaticReminderEventID = nil
        let messageSyncEvent = markMessageSyncPending(for: index)
        savePolls()
        await scheduler.unqueue(ids: reminderEvents)
        if let messageSyncEvent {
            await scheduler.schedule(messageSyncEvent)
        }
        return polls[index]
    }

    func cancelRepeat(id: String, userID: UserSnowflake, roles: [RoleSnowflake]) async throws -> [DatePoll] {
        guard let index = polls.firstIndex(where: { $0.id == id }) else {
            throw DatePollError.notFound(id)
        }
        try authorizeManagement(of: polls[index], userID: userID, roles: roles)
        guard polls[index].repeatIntervalWeeks != nil else {
            throw DatePollError.unavailablePoll
        }

        let seriesID = polls[index].repeatSeriesID ?? polls[index].id
        let indices = polls.indices.filter { polls[$0].repeatSeriesID == seriesID }
        let eventIDs = indices.compactMap { polls[$0].repeatEventID }
        var messageSyncEvents: [SchedulerEvent] = []
        for index in indices {
            polls[index].repeatIntervalWeeks = nil
            polls[index].repeatEventID = nil
            if let messageSyncEvent = markMessageSyncPending(for: index) {
                messageSyncEvents.append(messageSyncEvent)
            }
        }
        savePolls()
        if !eventIDs.isEmpty {
            await scheduler.unqueue(ids: eventIDs)
        }
        await scheduler.schedule(messageSyncEvents)
        return indices.map { polls[$0] }
    }

    private func nextIdentifier() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var identifier: String
        repeat {
            identifier = String((0..<Constants.identifierLength).map { _ in alphabet.randomElement()! })
        } while polls.contains(where: { $0.id == identifier })
        return identifier
    }

    private func schedulingEvents(for index: Int) -> [SchedulerEvent] {
        let pollID = polls[index].id
        var events: [SchedulerEvent] = []

        if polls[index].status == .open || polls[index].status == .awaitingFinalization {
            let closeEventID = polls[index].closeEventID ?? UUID()
            polls[index].closeEventID = closeEventID
            events.append(.init(id: closeEventID, dueDate: polls[index].deadline, eventType: .closeDatePoll(pollID: pollID)))
        }

        if let messageSyncEventID = polls[index].messageSyncEventID {
            events.append(.init(id: messageSyncEventID, dueDate: .now, eventType: .syncDatePollMessage(pollID: pollID)))
        }

        if let repeatIntervalWeeks = polls[index].repeatIntervalWeeks,
           polls[index].repeatEventCompleted != true,
           let repeatDate = Calendar.current.date(byAdding: .weekOfYear, value: repeatIntervalWeeks, to: polls[index].createdAt) {
            let repeatEventID = polls[index].repeatEventID ?? UUID()
            polls[index].repeatEventID = repeatEventID
            events.append(.init(id: repeatEventID, dueDate: repeatDate, eventType: .repeatDatePoll(pollID: pollID)))
        }

        if polls[index].status == .open,
           polls[index].automaticReminderEventID != nil || polls[index].automaticReminderDueDate == nil {
            let automaticReminderDate = polls[index].automaticReminderDueDate ?? min(
                polls[index].createdAt.addingTimeInterval(48 * 60 * 60),
                polls[index].createdAt.addingTimeInterval(polls[index].deadline.timeIntervalSince(polls[index].createdAt) / 2)
            )
            let automaticReminderEventID = polls[index].automaticReminderEventID ?? UUID()
            polls[index].automaticReminderDueDate = automaticReminderDate
            polls[index].automaticReminderEventID = automaticReminderEventID
            events.append(.init(
                id: automaticReminderEventID,
                dueDate: automaticReminderDate,
                eventType: .sendOutstandingDatePollReminders(pollID: pollID)
            ))
        }

        return events
    }

    private func markMessageSyncPending(for index: Int) -> SchedulerEvent? {
        guard polls[index].messageID != nil else { return nil }
        let event = SchedulerEvent(dueDate: .now, eventType: .syncDatePollMessage(pollID: polls[index].id))
        polls[index].messageSyncEventID = event.id
        return event
    }

    private func votePollIndex(
        pollID: String,
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
        return index
    }

    private func authorizeManagement(of poll: DatePoll, userID: UserSnowflake, roles: [RoleSnowflake]) throws {
        let permissionLevel = self.permissions.permissionsLevel(of: userID, roles: roles)
        guard
            poll.ownerID == userID
                || permissionLevel == .admin
                || (permissionLevel >= .dungeonMaster && roles.contains(poll.campaignRoleID))
        else {
            throw DatePollError.unauthorizedFinalization
        }
    }

    private func savePolls() {
        do {
            let data = try JSONEncoder().encode(polls)
            try data.write(to: dataPath)
        } catch {
            Self.logger.error("Failed to save date polls: \(error)")
        }
    }

    private static func loadPolls(from dataPath: URL) throws -> [DatePoll] {
        guard FileManager.default.fileExists(atPath: dataPath.path) else { return [] }
        do {
            return try JSONDecoder().decode([DatePoll].self, from: Data(contentsOf: dataPath))
        } catch {
            throw PersistentStateError.load(dataPath, error)
        }
    }
}
