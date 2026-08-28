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
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
    
    /// A date formatter for time strings
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
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
    }
    
    /// Returns a duration string for a given time interval
    static func durationString(for duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        let minutes = (seconds / 60) % 60
        let hours = seconds / 3600
        var string = "\(minutes)m"
        if hours > 0 {
            string = "\(hours)h \(string)"
        }
        return string
    }

    /// Returns a localized, user-facing duration string.
    static func durationString(
        for duration: TimeInterval,
        unitStyle: UnitStyle,
        localization: LocalizationContext
    ) -> String {
        if case .short = unitStyle { return durationString(for: duration) }

        let seconds = Int(duration.rounded())
        let minutes = (seconds / 60) % 60
        let hours = seconds / 3600
        let minuteKey = minutes == 1 ? "duration.minute" : "duration.minutes"
        let minuteString = localization.string(minuteKey, table: "Booking", String(minutes))
        guard hours > 0 else { return minuteString }

        let hourKey = hours == 1 ? "duration.hour" : "duration.hours"
        let hourString = localization.string(hourKey, table: "Booking", String(hours))
        guard minutes > 0 else { return hourString }
        return localization.string("duration.components", table: "Booking", hourString, minuteString)
    }
    
    /// Returns a time string for a given time in seconds from midnight
    static func timeString(for timeFromMidnight: TimeInterval) -> String {
        let time = date(on: .now, at: timeFromMidnight)
        return Utils.timeFormatter.string(from: time)
    }

    /// Returns seconds since midnight for a time parsed by `timeFormatter`.
    static func timeIntervalSinceStartOfDay(for time: Date, calendar: Calendar = .current) -> TimeInterval {
        let components = calendar.dateComponents([.hour, .minute, .second], from: time)
        return TimeInterval((components.hour ?? 0) * 3_600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
    }

    /// Returns a local wall-clock time on `day`, adjusting invalid DST times forward.
    static func date(on day: Date, at timeFromMidnight: TimeInterval, calendar: Calendar = .current) -> Date {
        let secondsPerDay = Int(GlobalConstants.secondsPerDay)
        let totalSeconds = ((Int(timeFromMidnight.rounded()) % secondsPerDay) + secondsPerDay) % secondsPerDay
        let hour = totalSeconds / 3_600
        let minute = (totalSeconds % 3_600) / 60
        let second = totalSeconds % 60
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: second,
            of: day,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? calendar.startOfDay(for: day)
    }
    
    static func createBookingEmbeds(
        for bookings: [any Booking],
        localization: LocalizationContext
    ) async throws -> [Embed] {
        let bookings = bookings.sorted(by: { $0.date < $1.date })
        
        var bookingEmbeds: [Embed] = []
        for booking in bookings {
            bookingEmbeds.append(try await Utils.createBookingEmbed(for: booking, localization: localization))
        }
        return bookingEmbeds
    }

    static func createBookingEmbed(
        for booking: any Booking,
        localization: LocalizationContext
    ) async throws -> Embed {
        let world: FoundryWorld?
        if let worldID = booking.worldID {
            world = try await PterodactylAPI.shared.world(for: worldID)
        } else {
            world = nil
        }
        
        var embed: Embed
        
        if let eventBooking = booking as? EventBooking {
            embed = createBookingEmbed(for: eventBooking, world: world?.title, localization: localization)
        } else {
            embed = createBookingEmbed(for: booking, world: world?.title, localization: localization)
        }
        
        if booking.wasCancelled {
            embed.title? += localization.string("embed.cancelled_suffix", table: "Booking")
        }
        embed.type = .rich
        
        if let author = try? await bot.client.getUser(id: booking.author).decode() {
            embed.footer = .init(text: localization.string(
                "embed.created_by",
                table: "Booking",
                author.global_name ?? author.username
            ))
        }
        
        return embed
    }

    static private func createBookingEmbed(
        for booking: EventBooking,
        world: String?,
        localization: LocalizationContext
    ) -> Embed {
        return .init(
            title: localization.dateTime(booking.date),
            description: ([
                world.map {
                    localization.string(
                        "embed.event_world",
                        table: "Booking",
                        DiscordUtils.mention(id: booking.campaignRoleSnowflake),
                        $0
                    )
                } ?? localization.string(
                    "embed.event_external",
                    table: "Booking",
                    DiscordUtils.mention(id: booking.campaignRoleSnowflake)
                ),
                booking.location.map {
                    localization.string("embed.voice_channel", table: "Booking", DiscordUtils.mention(id: $0))
                },
                "> \(booking.topic)",
            ].compactMap { $0 }).joined(separator: "\n")
        )
    }

    static func createBookingMessages(
        for bookings: [EventBooking],
        localization: LocalizationContext
    ) async throws -> [String] {
        let bookings = bookings.sorted(by: { $0.date < $1.date })
        let worlds = bookings.contains { $0.worldID != nil } ? try await PterodactylAPI.shared.worlds() : []

        var bookingMessages: [String] = []
        // We only show the last 10 bookings to avoid hitting Discord's character limit
        // TODO: Add pagination?
        for booking in bookings.suffix(10) {
            let world = booking.worldID.flatMap { worldID in worlds.first(where: { $0.id == worldID })?.title }
            let summary = world.map {
                localization.string(
                    "embed.event_world",
                    table: "Booking",
                    DiscordUtils.mention(id: booking.campaignRoleSnowflake),
                    $0
                )
            } ?? localization.string(
                "embed.event_external",
                table: "Booking",
                DiscordUtils.mention(id: booking.campaignRoleSnowflake)
            )
            let topic = booking.wasCancelled
                ? localization.string("history.cancelled_topic", table: "Booking", booking.topic)
                : booking.topic
            bookingMessages.append(
                """
                > \(localization.dateTime(booking.date))
                > \(summary)
                > \(topic)
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return bookingMessages
    }
    
    static private func createBookingEmbed(
        for booking: any Booking,
        world: String?,
        localization: LocalizationContext
    ) -> Embed {
        return .init(
            title: localization.formatDate(booking.date),
            description: world.map {
                localization.string(
                    "embed.reservation_world",
                    table: "Booking",
                    DiscordUtils.mention(id: booking.author),
                    $0
                )
            } ?? localization.string(
                "embed.reservation_external",
                table: "Booking",
                DiscordUtils.mention(id: booking.author)
            )
        )
    }
}
