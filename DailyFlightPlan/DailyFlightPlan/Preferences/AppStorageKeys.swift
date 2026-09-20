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

    /// Filter: show only missed (overdue, pending) items in the Log view
    case showMissedOnly

    /// Filter: show only completed/canceled items in the Log view (isolates, unlike the Day
    /// view's `showCompleted` which reveals them alongside everything else — kept as a separate
    /// key rather than sharing `showCompleted` so the same stored value can't mean two different
    /// things depending on which screen reads it)
    case showCompletedOnly

    /// Comma-separated EKCalendar identifiers to display (empty = show all calendars)
    case selectedCalendarIDs

    /// Comma-separated EKCalendar (reminder list) identifiers to display (empty = show all lists)
    case selectedReminderListIDs

    /// Filter: show calendar events inline (on by default)
    case showCalendarEvents

    /// Filter: show Reminders items inline (on by default)
    case showReminderItems

    /// Filter: show recurring habit instances (on by default)
    case showRecurring

    /// Category names currently selected for filtering (empty = no filter)
    case selectedCategoryNames

    var id: String { rawValue }
}
