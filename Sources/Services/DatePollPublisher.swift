import DiscordBM

enum DatePollPublisher {
    static func publish(
        poll: DatePoll,
        datePolls: DatePollsService,
        foundryFeaturesEnabled: Bool,
        client: any DiscordClient
    ) async throws {
        if let message = try await existingMessage(for: poll, client: client) {
            try await datePolls.publishPoll(id: poll.id, messageID: message.id)
            return
        }

        do {
            let message = try await client.createMessage(
                channelId: poll.channelID,
                payload: DatePollRenderer.createMessagePayload(for: poll, foundryFeaturesEnabled: foundryFeaturesEnabled)
            ).decode()
            try await datePolls.publishPoll(id: poll.id, messageID: message.id)
        } catch {
            if let message = try await existingMessage(for: poll, client: client) {
                try await datePolls.publishPoll(id: poll.id, messageID: message.id)
                return
            }
            throw error
        }
    }

    private static func existingMessage(
        for poll: DatePoll,
        client: any DiscordClient
    ) async throws -> DiscordChannel.Message? {
        guard let nonce = poll.publicationNonce else { return nil }
        let messages = try await client.listMessages(channelId: poll.channelID, limit: 100).decode()
        return messages.first { $0.nonce?.asString == nonce }
    }
}
