//
//  StringIntDoubleBool.swift
//  
//
//  Created by Jonas Frey on 14.04.24.
//

import DiscordBM

extension StringIntDoubleBool {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
    
    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        default:
            return nil
        }
    }
    
    var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        default:
            return nil
        }
    }
    
    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        default:
            return nil
        }
    }
}
