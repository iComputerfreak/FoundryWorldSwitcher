import DiscordBM

enum DatePollPublisher {
    static func publish(
        poll: DatePoll,
        datePolls: DatePollsService,
        client: any DiscordClient
    ) async throws {
        try await datePolls.withSerializedConfigUpdate {
            try await datePolls.withSerializedMessageUpdate(pollID: poll.id) {
                let currentPoll = try await datePolls.poll(id: poll.id)
                if let message = try await existingMessage(for: currentPoll, client: client) {
                    try await datePolls.publishPoll(id: currentPoll.id, messageID: message.id)
                    await datePolls.markMessageForSync(pollID: currentPoll.id)
                    return
                }

                let renderedConfiguration = await datePolls.renderConfiguration()
                do {
                    let message = try await client.createMessage(
                        channelId: currentPoll.channelID,
                        payload: DatePollRenderer.createMessagePayload(
                            for: currentPoll,
                            foundryFeaturesEnabled: renderedConfiguration.foundryFeaturesEnabled,
                            localization: renderedConfiguration.localization
                        )
                    ).decode()
                    try await datePolls.publishPoll(id: currentPoll.id, messageID: message.id)
                    if await datePolls.renderConfiguration() != renderedConfiguration {
                        await datePolls.markMessageForSync(pollID: currentPoll.id)
                    }
                } catch {
                    if let message = try await existingMessage(for: currentPoll, client: client) {
                        try await datePolls.publishPoll(id: currentPoll.id, messageID: message.id)
                        await datePolls.markMessageForSync(pollID: currentPoll.id)
                        return
                    }
                    throw error
                }
            }
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
