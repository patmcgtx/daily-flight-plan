//
//  CalendarService.swift
//  DailyFlightPlan
//
import Foundation

protocol CalendarService: AnyObject {
    /// Requests full calendar access from the user. Returns true if granted.
    func requestAccess() async -> Bool

    /// Returns true if the app currently has full calendar access.
    func hasAccess() -> Bool

    /// All calendars available to the app (for selection UI).
    func availableCalendars() -> [CalendarInfo]

    /// Timed (non-all-day) events for the given date from the specified calendars.
    /// Pass an empty set to fetch from all calendars.
    func events(for date: Date, calendarIDs: Set<String>) async -> [CalendarEvent]
}
