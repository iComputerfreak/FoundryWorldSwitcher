import DiscordBM
import Foundation
import Logging

enum DatePollMessageSynchronizer {
    private static let logger = Logger(label: String(describing: Self.self))

    static func synchronize(
        _ polls: [DatePoll],
        datePolls: DatePollsService,
        client: any DiscordClient
    ) async {
        for poll in polls {
            do {
                guard let eventID = poll.messageSyncEventID else { continue }
                try await synchronize(
                    pollID: poll.id,
                    eventID: eventID,
                    datePolls: datePolls,
                    client: client
                )
            } catch {
                logger.warning("Failed to synchronize date poll \(poll.id): \(error)")
            }
        }
    }

    static func synchronize(
        pollID: String,
        eventID: UUID,
        datePolls: DatePollsService,
        client: any DiscordClient
    ) async throws {
        try await datePolls.withSerializedMessageUpdate(pollID: pollID) {
            guard let poll = await datePolls.pollForMessageSync(pollID: pollID, eventID: eventID),
                  let messageID = poll.messageID else {
                return
            }
            let configuration = await datePolls.renderConfiguration()
            try await client.updateMessage(
                channelId: poll.channelID,
                messageId: messageID,
                payload: DatePollRenderer.messagePayload(
                    for: poll,
                    foundryFeaturesEnabled: configuration.foundryFeaturesEnabled,
                    localization: configuration.localization
                )
            ).guardSuccess()
            await datePolls.markMessageSynced(pollID: poll.id, eventID: eventID)
        }
    }

    static func synchronizeLatest(
        pollID: String,
        datePolls: DatePollsService,
        client: any DiscordClient
    ) async throws {
        try await datePolls.withSerializedMessageUpdate(pollID: pollID) {
            let poll = try await datePolls.poll(id: pollID)
            guard let messageID = poll.messageID else { throw DatePollError.missingMessageReference }
            let configuration = await datePolls.renderConfiguration()
            try await client.updateMessage(
                channelId: poll.channelID,
                messageId: messageID,
                payload: DatePollRenderer.messagePayload(
                    for: poll,
                    foundryFeaturesEnabled: configuration.foundryFeaturesEnabled,
                    localization: configuration.localization
                )
            ).guardSuccess()
            await datePolls.markMessageSynced(pollID: poll.id, eventID: poll.messageSyncEventID)
        }
    }
}
