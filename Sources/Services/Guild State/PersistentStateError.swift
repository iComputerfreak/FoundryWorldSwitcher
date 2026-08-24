import Foundation

/// Failure while loading or preparing persisted bot state.
enum PersistentStateError: LocalizedError {
    case load(URL, Error)
    case write(URL, Error)

    var errorDescription: String? {
        switch self {
        case let .load(url, error):
            return "Failed to load persistent state at \(url.path): \(error.localizedDescription)"
        case let .write(url, error):
            return "Failed to write persistent state at \(url.path): \(error.localizedDescription)"
        }
    }
}
