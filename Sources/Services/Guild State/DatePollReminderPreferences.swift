import DiscordBM
import Foundation
import Logging

/// Guild-local permanent opt-outs from automatic date-poll reminders.
actor DatePollReminderPreferences {
    /// User IDs that must not receive automatic date-poll reminders in this guild.
    private var optedOutUserIDs: Set<UserSnowflake>
    private let dataPath: URL
    private let logger = Logger(label: String(describing: DatePollReminderPreferences.self))

    init(dataPath: URL) throws {
        self.dataPath = dataPath
        do {
            guard FileManager.default.fileExists(atPath: dataPath.path) else {
                optedOutUserIDs = []
                return
            }
            optedOutUserIDs = try JSONDecoder().decode(Set<UserSnowflake>.self, from: Data(contentsOf: dataPath))
        } catch {
            throw PersistentStateError.load(dataPath, error)
        }
    }

    func optedOutUsers() -> Set<UserSnowflake> {
        optedOutUserIDs
    }

    func optOut(_ userID: UserSnowflake) {
        guard optedOutUserIDs.insert(userID).inserted else { return }
        save()
    }

    private func save() {
        do {
            try JSONEncoder().encode(optedOutUserIDs).write(to: dataPath)
        } catch {
            logger.error("Failed to save date-poll reminder preferences: \(error)")
        }
    }
}
