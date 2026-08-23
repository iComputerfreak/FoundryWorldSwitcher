//
//  DatePollMemberResolver.swift
//

import DiscordBM

enum DatePollMemberResolver {
    static func voterIDs(
        for roleID: RoleSnowflake,
        guildID: GuildSnowflake,
        client: any DiscordClient
    ) async throws -> Set<UserSnowflake> {
        var voters: Set<UserSnowflake> = []
        var after: UserSnowflake?
        while true {
            let members = try await client.listGuildMembers(guildId: guildID, limit: 1_000, after: after).decode()
            for member in members {
                guard let user = member.user, user.bot != true, member.roles.contains(roleID) else { continue }
                voters.insert(user.id)
            }
            guard members.count == 1_000, let lastUserID = members.last?.user?.id else { break }
            after = lastUserID
        }
        return voters
    }
}
