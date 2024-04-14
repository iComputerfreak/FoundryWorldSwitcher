//
//  Utils.swift
//  FoundryWorldSwitcher
//
//  Created by Jonas Frey on 29.12.23.
//

import Foundation
import DiscordBM
import Logging

enum Utils {
    private static let logger = Logger(label: "Utils")
    
    /// A date formatter for date strings
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    /// A date formatter for time strings
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    /// A date components formatter for durations
    static let dateComponentsFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.zeroFormattingBehavior = .dropAll
        f.allowedUnits = [.hour, .minute]
        return f
    }()
    
    /// The URL pointing to the directory the executable file is in.
    /// Crashes the program, if the app is unable to determine the base path.
    static var baseURL: URL {
        guard let baseURL = Bundle.main.executableURL?.deletingLastPathComponent() else {
            fatalError("Unable to construct executable directory.")
        }
        return baseURL
    }
    
    static var dataURL: URL {
        let configURL = baseURL.appendingPathComponent("data")
        var isDirectory: ObjCBool = false
        // If the config directory does not exist or it is not a directory, create a new one
        if !FileManager.default.fileExists(atPath: configURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            do {
                try FileManager.default.createDirectory(at: configURL, withIntermediateDirectories: true)
            } catch {
                logger.error("Error creating config directory: \(error)")
            }
        }
        return configURL
    }
}

// MARK: - Formatting
extension Utils {
    /// Returns a duration string for a given time interval
    static func durationString(for duration: TimeInterval) -> String {
        let reference = Date(timeIntervalSinceReferenceDate: 0)
        return dateComponentsFormatter.string(from: reference, to: reference.addingTimeInterval(duration)) ?? ""
    }
    
    /// Returns a time string for a given time in seconds from midnight
    static func timeString(for timeFromMidnight: TimeInterval) -> String {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let time = startOfDay.addingTimeInterval(timeFromMidnight)
        return Utils.timeFormatter.string(from: time)
    }
    
    static func createBookingEmbed(for booking: any Booking) async throws -> Embed {
        let world = try await PterodactylAPI.shared.world(for: booking.worldID)
        
        var embed: Embed
        
        if let eventBooking = booking as? EventBooking {
            embed = createBookingEmbed(for: eventBooking, world: world.title)
        } else {
            embed = createBookingEmbed(for: booking, world: world.title)
        }
        
        embed.type = .rich
        
        if let author = try? await bot.client.getUser(id: booking.author).decode() {
            embed.footer = .init(text: "Created by \(author.global_name ?? author.username)")
        }
        
        return embed
    }
    
    static private func createBookingEmbed(for booking: EventBooking, world: String) -> Embed {
        let date = Utils.dateFormatter.string(from: booking.date)
        let time = Utils.timeFormatter.string(from: booking.date)
        
        return .init(
            title: "\(date) at \(time)",
            description: """
            \(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) is playing in the world '\(world)'.
            > \(booking.topic)
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    static private func createBookingEmbed(for booking: any Booking, world: String) -> Embed {
        let date = Utils.dateFormatter.string(from: booking.date)
        
        return .init(
            title: date,
            description: """
            \(DiscordUtils.mention(id: booking.author)) is preparing the world '\(world)'.
            """.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
