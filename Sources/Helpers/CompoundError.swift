// Copyright © 2024 Jonas Frey. All rights reserved.

import Foundation

struct CompoundError: LocalizedError, CustomStringConvertible {
    let errors: [Error]
    
    var errorDescription: String? {
        "\(errors.count) Errors:\n" + errors.map { "  - \($0.localizedDescription)" }.joined(separator: "\n")
    }
    
    var description: String {
        "\(errors.count) Errors:\n" + errors.map { "  - \($0)" }.joined(separator: "\n")
    }
    
    init(errors: [Error]) {
        assert(errors.count > 1, "CompoundError must contain at least two errors.")
        self.errors = errors
    }
}
