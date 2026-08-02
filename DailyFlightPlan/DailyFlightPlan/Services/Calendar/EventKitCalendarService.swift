//
//  EventKitCalendarService.swift
//  DailyFlightPlan
//
import EventKit
import SwiftUI

final class EventKitCalendarService: CalendarService {

    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else {
            return status == .fullAccess
        }
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func hasAccess() -> Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func availableCalendars() -> [CalendarInfo] {
        store.calendars(for: .event).map {
            CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: Color(cgColor: $0.cgColor))
        }
    }

    func events(for date: Date, calendarIDs: Set<String>) async -> [CalendarEvent] {
        guard hasAccess() else { return [] }

        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        let allCalendars = store.calendars(for: .event)
        let selected: [EKCalendar]? = calendarIDs.isEmpty ? nil : allCalendars.filter {
            calendarIDs.contains($0.calendarIdentifier)
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selected)
        let ekEvents = store.events(matching: predicate)

        return ekEvents
            .filter { !$0.isAllDay }
            .compactMap { event -> CalendarEvent? in
                guard let id = event.eventIdentifier,
                      let title = event.title,
                      let start = event.startDate,
                      let end = event.endDate,
                      let calendar = event.calendar else { return nil }
                return CalendarEvent(
                    id: id,
                    title: title,
                    startDate: start,
                    endDate: end,
                    calendarTitle: calendar.title,
                    calendarColor: Color(cgColor: calendar.cgColor)
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }
}
