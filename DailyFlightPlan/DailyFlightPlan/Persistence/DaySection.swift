//
//  DaySection.swift
//  DailyFlightPlan
//
import Foundation

/// The five time-of-day sections that organize the day view
enum DaySection: String, CaseIterable, Codable, Identifiable {

    case morning
    case midday
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning:   return "Morning"
        case .midday:    return "Midday"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        case .night:     return "Night"
        }
    }

    /// Earliest hour (24h) at which this section begins
    var startHour: Int {
        switch self {
        case .morning:   return 0
        case .midday:    return 11
        case .afternoon: return 13
        case .evening:   return 17
        case .night:     return 20
        }
    }

    /// Last hour (24h) at which this section ends (inclusive)
    var endHour: Int {
        switch self {
        case .morning:   return 10
        case .midday:    return 12
        case .afternoon: return 16
        case .evening:   return 19
        case .night:     return 23
        }
    }

    /// Returns the section that contains the given date's hour, or nil if none match
    static func containing(_ date: Date) -> DaySection? {
        let hour = Calendar.current.component(.hour, from: date)
        return DaySection.allCases.first { hour >= $0.startHour && hour <= $0.endHour }
    }
}
