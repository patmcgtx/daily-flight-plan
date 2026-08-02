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

    /// Comma-separated EKCalendar (reminder list) identifiers to display (empty = show all lists)
    case selectedReminderListIDs

    /// Filter: show calendar events inline (on by default)
    case showCalendarEvents

    /// Filter: show Reminders items inline (on by default)
    case showReminderItems

    var id: String { rawValue }
}
