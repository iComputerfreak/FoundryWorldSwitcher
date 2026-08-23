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
    
    let dataPath: URL
    private(set) var events: [SchedulerEvent]
    private var isUpdating = false
    
    init(dataPath: URL) {
        self.dataPath = dataPath
        events = Self.loadEvents(from: dataPath)
    }
    
    func update(in context: GuildContext) async throws {
        try await update(using: { event in
            try await event.execute(in: context)
        })
    }

    private func update(using executor: (SchedulerEvent) async throws -> Void) async throws {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        var errors: [Error] = []
        for event in dueEvents() {
            Self.logger.info("Executing scheduled event: \(event)")
            do {
                try await executor(event)
                unqueue(event)
            } catch {
                errors.append(error)
                Self.logger.error("Error executing scheduled event \(event.id): \(error)")
            }
        }
        if errors.count > 1 {
            throw CompoundError(errors: errors)
        } else if let error = errors.first {
            throw error
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
        unqueue(ids: events.map(\.id))
    }

    /// Removes events with the given IDs from the scheduler queue.
    func unqueue(ids eventIDs: [SchedulerEvent.ID]) {
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
            try data.write(to: dataPath)
        } catch {
            Self.logger.error("Failed to save events: \(error)")
        }
    }
    
    static func loadEvents(from dataPath: URL) -> [SchedulerEvent] {
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
