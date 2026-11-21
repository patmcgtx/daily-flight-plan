//
//  MockCalendarService.swift
//  DailyFlightPlan
//
#if DEBUG
import SwiftUI

final class MockCalendarService: CalendarService {

    func requestAccess() async -> Bool { true }

    func hasAccess() -> Bool { true }

    func availableCalendars() -> [CalendarInfo] {
        [
            CalendarInfo(id: "work", title: "Work", color: .blue),
            CalendarInfo(id: "personal", title: "Personal", color: .green),
        ]
    }

    func events(for date: Date, calendarIDs: Set<String>) async -> [CalendarEvent] {
        let cal = Calendar.current
        guard cal.isDateInToday(date) else { return [] }

        let allEvents: [(calendarID: String, event: CalendarEvent)] = [
            ("work", CalendarEvent(
                id: "mock-1",
                title: "Team Standup",
                startDate: cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)!,
                endDate: cal.date(bySettingHour: 9, minute: 30, second: 0, of: date)!,
                calendarTitle: "Work",
                calendarColor: .blue
            )),
            ("personal", CalendarEvent(
                id: "mock-2",
                title: "Lunch with Alex",
                startDate: cal.date(bySettingHour: 12, minute: 0, second: 0, of: date)!,
                endDate: cal.date(bySettingHour: 13, minute: 0, second: 0, of: date)!,
                calendarTitle: "Personal",
                calendarColor: .green
            )),
            ("personal", CalendarEvent(
                id: "mock-3",
                title: "Sam's Birthday",
                startDate: cal.startOfDay(for: date),
                endDate: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!,
                calendarTitle: "Personal",
                calendarColor: .green,
                isAllDay: true
            )),
        ]

        if calendarIDs.isEmpty {
            return allEvents.map(\.event)
        }
        return allEvents.filter { calendarIDs.contains($0.calendarID) }.map(\.event)
    }
}
#endif
