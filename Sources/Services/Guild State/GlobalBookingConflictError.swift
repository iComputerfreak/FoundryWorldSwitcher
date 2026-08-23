import Foundation

/// Error raised when a booking interval overlaps an existing global booking.
enum GlobalBookingConflictError: LocalizedError {
    /// The conflicting booking record.
    case conflict(GlobalBookingRecord)

    /// User-facing booking conflict explanation.
    var errorDescription: String? {
        switch self {
        case .conflict:
            return "The Foundry server is already booked during that interval."
        }
    }
}
