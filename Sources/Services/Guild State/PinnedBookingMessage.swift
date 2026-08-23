import DiscordBM

/// A guild message displaying bookings filtered by an optional world or role.
struct PinnedBookingMessage: Codable {
    /// Channel containing the message.
    let channelID: ChannelSnowflake

    /// Discord message to refresh after booking changes.
    let messageID: MessageSnowflake

    /// Optional world filter.
    let worldID: String?

    /// Optional campaign role filter.
    let role: RoleSnowflake?
}
