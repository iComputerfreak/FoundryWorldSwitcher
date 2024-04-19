//
//  Scheduler.swift
//
//
//  Created by Jonas Frey on 11.04.24.
//

import DiscordBM
import Foundation
import Logging

actor Scheduler {
    static var logger: Logger = .init(label: String(describing: Scheduler.self))
    static var dataPath: URL = Utils.dataURL.appendingPathComponent("events.json")
    static let shared: Scheduler = .init()
    
    private(set) var events: [SchedulerEvent]
    
    init() {
        events = Self.loadEvents()
    }
    
    /// Checks for due events and executes them
    func update() async throws {
        for event in dueEvents() {
            Self.logger.info("Executing scheduled event: \(event)")
            try await event.execute()
            unqueue(event)
        }
    }
    
    /// Schedules new events to be executed
    func schedule(_ events: [SchedulerEvent]) {
        let eventsString = events.map({ "- \($0)" }).joined(separator: "\n")
        Self.logger.info("Scheduled \(events.count) new events:\n\(eventsString)")
        self.events.append(contentsOf: events)
        saveEvents()
    }
    
    /// Schedules a new event to be executed
    func schedule(_ event: SchedulerEvent) {
        Self.logger.info("Scheduled new event: \(event)")
        events.append(event)
        saveEvents()
    }
    
    /// Removes multiple events from the scheduler queue
    func unqueue(_ events: [SchedulerEvent]) {
        let eventIDs = events.map(\.id)
        let eventIDsString = eventIDs.map({ "- \($0.uuidString)" }).joined(separator: "\n")
        Self.logger.info("Unqueued scheduled events with the following IDs:\n\(eventIDsString)")
        self.events.removeAll(where: { eventIDs.contains($0.id) })
        saveEvents()
    }
    
    /// Removes an event from the scheduler queue
    func unqueue(_ event: SchedulerEvent) {
        unqueue(id: event.id)
    }
    
    /// Removes an event from the scheduler queue
    func unqueue(id eventID: SchedulerEvent.ID) {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            Self.logger.warning("Tried to remove non-existent event with ID \(eventID)")
            return
        }
        Self.logger.info("Unqueued scheduled event: \(events[index])")
        events.remove(at: index)
        saveEvents()
    }
    
    /// Returns all events that are due to be executed, sorted by their due date
    private func dueEvents() -> [SchedulerEvent] {
        events
            .filter { event in
                event.dueDate <= .now
            }
            .sorted {
                $0.dueDate < $1.dueDate
            }
    }
}

// MARK: - Saving
extension Scheduler {
    func saveEvents() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: Self.dataPath)
        } catch {
            Self.logger.error("Failed to save events: \(error)")
        }
    }
    
    static func loadEvents() -> [SchedulerEvent] {
        do {
            guard FileManager.default.fileExists(atPath: dataPath.path) else {
                return []
            }
            let data = try Data(contentsOf: dataPath)
            return try JSONDecoder().decode([SchedulerEvent].self, from: data)
        } catch {
            logger.error("Failed to load events: \(error)")
            return []
        }
    }
}
