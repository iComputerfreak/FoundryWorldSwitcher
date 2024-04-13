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
    static var dataPath: URL = Utils.baseURL.appendingPathComponent("events.json")
    static let shared: Scheduler = .init()
    
    private(set) var events: [SchedulerEvent]
    
    init() {
        events = Self.loadEvents()
    }
    
    /// Checks for due events and executes them
    func update() async throws {
        for event in dueEvents() {
            try await event.execute()
            unqueue(event)
        }
    }
    
    /// Schedules a new event to be executed
    func schedule(_ event: SchedulerEvent) {
        events.append(event)
        saveEvents()
    }
    
    func unqueue(_ event: SchedulerEvent) {
        unqueue(id: event.id)
    }
    
    func unqueue(id eventID: SchedulerEvent.ID) {
        events.removeAll(where: { $0.id == eventID })
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
            let data = try Data(contentsOf: dataPath)
            return try JSONDecoder().decode([SchedulerEvent].self, from: data)
        } catch {
            logger.error("Failed to load events: \(error)")
            return []
        }
    }
}
