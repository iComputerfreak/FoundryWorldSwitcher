//
//  DiscordClient+respond.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import DiscordBM

extension DiscordClient {
    /// Responds to an interaction with a message
    func respond(token: String, message: String) async throws {
        try await updateOriginalInteractionResponse(
            token: token,
            payload: .init(content: message)
        ).guardSuccess()
    }
    
    /// Responds to an interaction with a message payload
    func respond(token: String, payload: Payloads.EditWebhookMessage) async throws {
        try await updateOriginalInteractionResponse(
            token: token,
            payload: payload
        ).guardSuccess()
    }
    
    /// Returns the name of the given role in the given guild, or `nil`, if no role with the given snowflake exists in the guild
    func roleName(of snowflake: RoleSnowflake, in guild: GuildSnowflake) async throws -> String? {
        let roles = try await listGuildRoles(id: guild).decode()
        return roles
            .first(where: { role in
                role.id == snowflake
            })?
            .name
    }
    
    /// Creates a new server event for the given booking in the given guild
    func createServerEvent(for booking: EventBooking, in guild: GuildSnowflake) async throws {
        let eventTitle: String = try await {
            if let roleName = try await roleName(of: booking.campaignRoleSnowflake, in: guild) {
                return "\(roleName) - \(booking.topic)"
            } else {
                return booking.topic
            }
        }()
        
        try await createGuildScheduledEvent(
            guildId: guild,
            payload: .init(
                channel_id: booking.location,
                name: eventTitle,
                privacy_level: .guildOnly,
                scheduled_start_time: .init(date: booking.date),
                scheduled_end_time: .init(date: booking.date.addingTimeInterval(BotConfig.shared.sessionLength)),
                entity_type: .voice
            )
        ).guardSuccess()
    }
}
