import Foundation

/// Language used for all user-facing output in one guild.
enum GuildLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case german = "de"

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en")
        case .german: Locale(identifier: "de")
        }
    }

    init?(configValue: String) {
        switch configValue.lowercased() {
        case "en", "english": self = .english
        case "de", "german", "deutsch": self = .german
        default: return nil
        }
    }
}
