import Foundation

enum DatePollAction: String {
    case create
    case vote
    case finalize
    case edit
    case view
    case book
    case remind
    case delay
    case optOut = "optout"
    case cancel
    case cancelRepeat = "cancel-repeat"
}
