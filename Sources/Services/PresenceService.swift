import DiscordBM
import Foundation
import Logging

/// Publishes the current Foundry world and global world-lock state as the bot activity state.
actor PresenceService {
    private static let activityName = "Foundry VTT"
    private static let maximumStateLength = 128
    private static let worldRefreshInterval: TimeInterval = 5 * 60
    private static let minorWords: Set<String> = [
        "a", "an", "and", "as", "at", "but", "by", "for", "from", "in", "nor", "of", "on", "or", "the", "to", "via", "vs"
    ]

    private let logger = Logger(label: String(describing: PresenceService.self))
    private let gatewayManager: any GatewayManager
    private let guildRegistry: GuildRegistry
    private var cachedWorldName: String?
    private var lastWorldRefresh: Date?
    private var lastPublishedState: String?
    private var hasPublishedPresence = false

    init(gatewayManager: any GatewayManager, guildRegistry: GuildRegistry) {
        self.gatewayManager = gatewayManager
        self.guildRegistry = guildRegistry
    }

    func refresh(forceWorldRefresh: Bool = false) async {
        guard await guildRegistry.hasFoundryFeaturesEnabled() else {
            await publish(state: nil)
            return
        }

        if forceWorldRefresh || shouldRefreshWorld {
            do {
                let world = try await PterodactylAPI.shared.currentWorld()
                cachedWorldName = Self.humanizedWorldName(world.title)
                lastWorldRefresh = .now
            } catch {
                lastWorldRefresh = .now
                logger.warning("Unable to refresh current Foundry world for presence: \(error)")
            }
        }

        guard let cachedWorldName else {
            await publish(state: nil)
            return
        }

        let lockState: PresenceLockState
        do {
            lockState = try await guildRegistry.presenceLockState()
        } catch {
            logger.warning("Unable to refresh world-lock state for presence: \(error)")
            return
        }
        await publish(state: Self.state(worldName: cachedWorldName, lockState: lockState))
    }

    private var shouldRefreshWorld: Bool {
        guard let lastWorldRefresh else { return true }
        return lastWorldRefresh.addingTimeInterval(Self.worldRefreshInterval) <= .now
    }

    private func publish(state: String?) async {
        guard !hasPublishedPresence || state != lastPublishedState else { return }
        await gatewayManager.updatePresence(
            payload: .init(
                activities: [.init(name: Self.activityName, type: .game, state: state)],
                status: .online,
                afk: false
            )
        )
        lastPublishedState = state
        hasPublishedPresence = true
    }

    private static func state(worldName: String, lockState: PresenceLockState) -> String {
        let suffix: String
        switch lockState {
        case .unlocked:
            suffix = " · 🔓 Unlocked"
        case let .locked(until: date):
            if let date {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "EEE HH:mm"
                suffix = " · 🔒 Locked until \(formatter.string(from: date))"
            } else {
                suffix = " · 🔒 Locked"
            }
        }

        let prefix = "🌍 "
        let availableWorldLength = max(0, maximumStateLength - prefix.count - suffix.count)
        let displayedWorldName = String(worldName.prefix(availableWorldLength))
        return prefix + displayedWorldName + suffix
    }

    private static func humanizedWorldName(_ name: String) -> String {
        guard name.contains("_") else { return name }
        let words = name.split(separator: "_", omittingEmptySubsequences: true).map(String.init)
        return words.enumerated().map { index, word in
            if word.count > 1, word == word.uppercased() {
                return word
            }
            let lowercaseWord = word.lowercased()
            if index > 0, index < words.count - 1, minorWords.contains(lowercaseWord) {
                return lowercaseWord
            }
            return lowercaseWord.prefix(1).uppercased() + lowercaseWord.dropFirst()
        }.joined(separator: " ")
    }
}

enum PresenceLockState: Equatable, Sendable {
    case unlocked
    case locked(until: Date?)
}
