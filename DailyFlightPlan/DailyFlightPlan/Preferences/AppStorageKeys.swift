//
//  AppStorageKeys.swift
//  DailyFlightPlan
//

/// Keys for all @AppStorage values in the app
enum AppStorageKeys: String, CaseIterable, Identifiable {

    /// The selected UI theme
    case theme

    /// Filter: show only flagged/important items
    case showFlaggedOnly

    /// Filter: show completed and canceled items
    case showCompleted

    /// Filter: show recurring items (on by default)
    case showRecurring

    /// Comma-separated EKCalendar identifiers to display (empty = show all calendars)
    case selectedCalendarIDs

    var id: String { rawValue }
}
