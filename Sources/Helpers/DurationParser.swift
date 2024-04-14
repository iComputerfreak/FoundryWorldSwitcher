//
//  DurationParser.swift
//
//
//  Created by Jonas Frey on 14.04.24.
//

import Foundation
import RegexBuilder

enum DurationParserError: LocalizedError {
    case couldNotParseHoursOrMinutes
    case wrongFormat
    
    var errorDescription: String? {
        switch self {
        case .couldNotParseHoursOrMinutes:
            return "Could not parse hours or minutes. Please provide at least one of them in the format '1h 2m'."
            
        case .wrongFormat:
            return "The duration string is in the wrong format. Please provide a duration in the format '1h 2m'."
        }
    }
}

/// A helper class to parse durations from strings
enum DurationParser {
    static func duration(from string: String) throws -> TimeInterval {
        let hourReference = Reference(String?.self)
        let minuteReference = Reference(String?.self)
        // E.g., '1h 2m', '1h2m', '1 hour, 2 minutes'
        let regex = Regex {
            Optionally {
                TryCapture(OneOrMore(.digit), as: hourReference) { (value: Substring) -> String? in
                    String(value)
                }
                ZeroOrMore(.whitespace)
                "h"
                Optionally {
                    ChoiceOf {
                        "our"
                        "r"
                    }
                    Optionally("s")
                }
            }
            
            ZeroOrMore {
                ChoiceOf {
                    .whitespace
                    ","
                    "."
                }
            }
            
            Optionally {
                TryCapture(OneOrMore(.digit), as: hourReference) { (value: Substring) -> String? in
                    String(value)
                }
                ZeroOrMore(.whitespace)
                "m"
                Optionally {
                    "in"
                    Optionally("utes")
                }
            }
        }
        
        if let matches = try? regex.firstMatch(in: string) {
            // We need at least one of the two references to be available
            guard matches[hourReference] != nil || matches[minuteReference] != nil else {
                throw DurationParserError.couldNotParseHoursOrMinutes
            }
            var duration: TimeInterval = 0
            if
                let hourString = matches[hourReference],
                let hour = Int(hourString)
            {
                duration += Double(hour) * GlobalConstants.secondsPerHour
            }
            if
                let minuteString = matches[minuteReference],
                let minute = Int(minuteString)
            {
                duration += Double(minute) * GlobalConstants.secondsPerMinute
            }
            return duration
        } else {
            throw DurationParserError.wrongFormat
        }
    }
}
