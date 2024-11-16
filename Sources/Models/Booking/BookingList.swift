// Copyright © 2024 Jonas Frey. All rights reserved.

import Foundation

struct BookingList: Codable {
    var events: [EventBooking]
    var reservations: [ReservationBooking]
    
    var allBookings: [any Booking] {
        get {
            events + reservations
        }
        set {
            events = newValue.compactMap { $0 as? EventBooking }
            reservations = newValue.compactMap { $0 as? ReservationBooking }
        }
    }
    
    init(bookings: [any Booking]) {
        self.events = bookings.compactMap { $0 as? EventBooking }
        self.reservations = bookings.compactMap { $0 as? ReservationBooking }
    }
}
