//
//  BookingsService.swift
//
//
//  Created by Jonas Frey on 12.04.24.
//

import DiscordBM
import Foundation

protocol BookingsService {
    var bookings: [Booking] { get }
    func createBooking(at date: Date, author: UserSnowflake, worldID: String, roleSnowflake: RoleSnowflake?) async throws
    func deleteBooking(_ booking: Booking) async throws
    func deleteBooking(id: Booking.ID) async throws
}
