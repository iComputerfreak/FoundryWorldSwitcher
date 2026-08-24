import DiscordBM
import Logging

enum DatePollMessageSynchronizer {
    private static let logger = Logger(label: String(describing: Self.self))

    static func synchronize(
        _ polls: [DatePoll],
        datePolls: DatePollsService,
        foundryFeaturesEnabled: Bool,
        client: any DiscordClient
    ) async {
        for poll in polls {
            guard let messageID = poll.messageID else { continue }
            do {
                try await client.updateMessage(
                    channelId: poll.channelID,
                    messageId: messageID,
                    payload: DatePollRenderer.messagePayload(for: poll, foundryFeaturesEnabled: foundryFeaturesEnabled)
                ).guardSuccess()
                await datePolls.markMessageSynced(pollID: poll.id, eventID: poll.messageSyncEventID)
            } catch {
                logger.warning("Failed to synchronize date poll \(poll.id): \(error)")
            }
        }
    }
}
