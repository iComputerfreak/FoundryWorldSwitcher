//
//  DiscordClient+respond.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 02.01.24.
//

import DiscordBM

extension DiscordClient {
    func respond(token: String, message: String) async throws {
        try await updateOriginalInteractionResponse(
            token: token,
            payload: .init(content: message)
        ).guardSuccess()
    }
}
