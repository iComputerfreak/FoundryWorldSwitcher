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
    
    /// A date formatter for displaying date strings
    static let outputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    /// A date formatter for user-typed dates
    static let inputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
    
    /// A date formatter for time strings
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
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
    enum UnitStyle {
        case short
        case long
        
        var minutesString: String {
            switch self {
            case .short: return "m"
            case .long: return " minutes"
            }
        }
        
        var hoursString: String {
            switch self {
            case .short: return "h"
            case .long: return " hours"
            }
        }
    }
    
    /// Returns a duration string for a given time interval
    static func durationString(for duration: TimeInterval, unitStyle: UnitStyle = .short) -> String {
        let seconds = Int(duration.rounded())
        let minutes = (seconds / 60) % 60
        let hours = seconds / 3600
        var string = "\(minutes)\(unitStyle.minutesString)"
        if hours > 0 {
            string = "\(hours)\(unitStyle.hoursString) \(string)"
        }
        return string
    }
    
    /// Returns a time string for a given time in seconds from midnight
    static func timeString(for timeFromMidnight: TimeInterval) -> String {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let time = startOfDay.addingTimeInterval(timeFromMidnight)
        return Utils.timeFormatter.string(from: time)
    }
    
    static func createBookingEmbeds(for bookings: [any Booking]) async throws -> [Embed] {
        let bookings = bookings.sorted(by: { $0.date < $1.date })
        
        var bookingEmbeds: [Embed] = []
        for booking in bookings {
            bookingEmbeds.append(try await Utils.createBookingEmbed(for: booking))
        }
        return bookingEmbeds
    }

    static func createBookingEmbed(for booking: any Booking) async throws -> Embed {
        let world: FoundryWorld?
        if let worldID = booking.worldID {
            world = try await PterodactylAPI.shared.world(for: worldID)
        } else {
            world = nil
        }
        
        var embed: Embed
        
        if let eventBooking = booking as? EventBooking {
            embed = createBookingEmbed(for: eventBooking, world: world?.title)
        } else {
            embed = createBookingEmbed(for: booking, world: world?.title)
        }
        
        if booking.wasCancelled {
            embed.title? += " (Cancelled)"
        }
        embed.type = .rich
        
        if let author = try? await bot.client.getUser(id: booking.author).decode() {
            embed.footer = .init(text: "Created by \(author.global_name ?? author.username)")
        }
        
        return embed
    }

    static private func createBookingEmbed(for booking: EventBooking, world: String?) -> Embed {
        let date = Utils.outputDateFormatter.string(from: booking.date)
        let time = Utils.timeFormatter.string(from: booking.date)

        return .init(
            title: "\(date) at \(time)",
            description: ([
                world.map { "\(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) is playing in the world '\($0)'." }
                    ?? "\(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) has a session.",
                booking.location.map { "Voice channel: \(DiscordUtils.mention(id: $0))." },
                "> \(booking.topic)",
            ].compactMap { $0 }).joined(separator: "\n")
        )
    }

    static func createBookingMessages(for bookings: [EventBooking]) async throws -> [String] {
        let bookings = bookings.sorted(by: { $0.date < $1.date })
        let worlds = bookings.contains { $0.worldID != nil } ? try await PterodactylAPI.shared.worlds() : []

        var bookingMessages: [String] = []
        // We only show the last 10 bookings to avoid hitting Discord's character limit
        // TODO: Add pagination?
        for booking in bookings.suffix(10) {
            let date = Utils.outputDateFormatter.string(from: booking.date)
            let time = Utils.timeFormatter.string(from: booking.date)
            let world = booking.worldID.flatMap { worldID in worlds.first(where: { $0.id == worldID })?.title }
            bookingMessages.append(
                """
                > \(date) at \(time)
                > \(world.map { "\(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) is playing in the world '\($0)'." } ?? "\(DiscordUtils.mention(id: booking.campaignRoleSnowflake)) has a session.")
                > \(booking.wasCancelled ? "~~\(booking.topic)~~ (cancelled)" : booking.topic)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return bookingMessages
    }
    
    static private func createBookingEmbed(for booking: any Booking, world: String?) -> Embed {
        let date = Utils.outputDateFormatter.string(from: booking.date)
        
        return .init(
            title: date,
            description: world.map {
                "\(DiscordUtils.mention(id: booking.author)) is preparing the world '\($0)'."
            } ?? "\(DiscordUtils.mention(id: booking.author)) has an external booking."
        )
    }
}
