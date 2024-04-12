//
//  Scheduler.swift
//  
//
//  Created by Jonas Frey on 11.04.24.
//

import DiscordBM
import Foundation
import Logging

actor Scheduler: Savable {
    static var logger: Logger = .init(label: String(describing: Scheduler.self))
    static var dataPath: URL = Utils.baseURL.appending(path: "events.json")
    
    var events: [SchedulerEvent]
    
    init() {
        events = []
    }
    
    /// Checks for due events and executes them
    func update() async throws {
        for event in dueEvents() {
            try await event.execute()
        }
    }
    
    /// Schedules a new event to be executed
    func schedule(_ event: SchedulerEvent) {
        events.append(event)
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
