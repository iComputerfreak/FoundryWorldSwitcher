import Foundation

/// Immutable localization and display-formatting context for one guild operation.
struct LocalizationContext: Sendable {
    static let english = LocalizationContext(language: .english)

    let language: GuildLanguage

    var locale: Locale { language.locale }

    func string(_ key: String, table: String = "Localizable", _ arguments: CVarArg...) -> String {
        let value = localizedString(key, table: table, language: language)
        guard !arguments.isEmpty else { return value }
        return String(format: value, locale: locale, arguments: arguments)
    }

    func formatDate(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .none) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    func dateTime(_ date: Date) -> String {
        formatDate(date, dateStyle: .medium, timeStyle: .short)
    }

    private func localizedString(_ key: String, table: String, language: GuildLanguage) -> String {
        guard let bundle = Self.bundle(for: language) else { return key }
        let value = bundle.localizedString(forKey: key, value: nil, table: table)
        if value != key || language == .english {
            return value
        }
        return Self.bundle(for: .english)?.localizedString(forKey: key, value: key, table: table) ?? key
    }

    private static func bundle(for language: GuildLanguage) -> Bundle? {
        guard let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
