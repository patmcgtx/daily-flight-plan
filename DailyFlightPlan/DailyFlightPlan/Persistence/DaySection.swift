//
//  DaySection.swift
//  DailyFlightPlan
//
import Foundation

/// The six time-of-day sections that organize the day view
enum DaySection: String, CaseIterable, Codable, Identifiable {

    case firstThing
    case morning
    case midday
    case afternoon
    case evening
    case bedtime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstThing:  return "First Thing"
        case .morning:     return "Morning"
        case .midday:      return "Midday"
        case .afternoon:   return "Afternoon"
        case .evening:     return "Evening"
        case .bedtime:     return "Bedtime"
        }
    }

    /// Minutes since midnight at which this section begins
    var startMinutes: Int {
        switch self {
        case .firstThing:  return 0            // midnight
        case .morning:     return 7 * 60 + 30  // 7:30 AM
        case .midday:      return 11 * 60       // 11:00 AM
        case .afternoon:   return 13 * 60       // 1:00 PM
        case .evening:     return 17 * 60       // 5:00 PM
        case .bedtime:     return 22 * 60       // 10:00 PM
        }
    }

    /// Minutes since midnight at which this section ends (inclusive)
    var endMinutes: Int {
        switch self {
        case .firstThing:  return 7 * 60 + 29   // 7:29 AM
        case .morning:     return 10 * 60 + 59  // 10:59 AM
        case .midday:      return 12 * 60 + 59  // 12:59 PM
        case .afternoon:   return 16 * 60 + 59  // 4:59 PM
        case .evening:     return 21 * 60 + 59  // 9:59 PM
        case .bedtime:     return 23 * 60 + 59  // 11:59 PM
        }
    }

    /// Earliest hour (24h) — derived from startMinutes
    var startHour: Int { startMinutes / 60 }

    /// Last hour (24h) inclusive — derived from endMinutes
    var endHour: Int { endMinutes / 60 }

    /// Human-readable time range shown in section headers
    /// Phase 16: replace with dynamic computation from @AppStorage-backed boundaries.
    var timeRangeLabel: String {
        switch self {
        case .firstThing:  return "before 7:30 AM"
        case .morning:     return "7:30 – 11 AM"
        case .midday:      return "11 AM – 1 PM"
        case .afternoon:   return "1 – 5 PM"
        case .evening:     return "5 – 10 PM"
        case .bedtime:     return "10 PM – midnight"
        }
    }

    /// Returns the section that contains the given date's time, or nil if none match
    static func containing(_ date: Date) -> DaySection? {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return DaySection.allCases.first { minutes >= $0.startMinutes && minutes <= $0.endMinutes }
    }
}
