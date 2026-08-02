//
//  RemindersService.swift
//  DailyFlightPlan
//
import Foundation

protocol RemindersService: AnyObject {
    /// Requests full Reminders access from the user. Returns true if granted.
    func requestAccess() async -> Bool

    /// Returns true if the app currently has full Reminders access.
    func hasAccess() -> Bool

    /// All reminder lists available to the app (for selection UI).
    func availableReminderLists() -> [ReminderListInfo]

    /// Incomplete reminders due on the given date from the specified lists.
    /// Pass an empty set to fetch from all lists.
    func reminders(for date: Date, listIDs: Set<String>) async -> [ReminderItem]
}
