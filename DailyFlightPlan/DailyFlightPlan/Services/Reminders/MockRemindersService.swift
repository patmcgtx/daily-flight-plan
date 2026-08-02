//
//  MockRemindersService.swift
//  DailyFlightPlan
//
#if DEBUG
import SwiftUI

final class MockRemindersService: RemindersService {

    func requestAccess() async -> Bool { true }
    func hasAccess() -> Bool { true }

    func availableReminderLists() -> [ReminderListInfo] {
        [
            ReminderListInfo(id: "home", title: "Home", color: .orange),
            ReminderListInfo(id: "work", title: "Work", color: .blue),
        ]
    }

    func reminders(for date: Date, listIDs: Set<String>) async -> [ReminderItem] {
        let cal = Calendar.current
        guard cal.isDateInToday(date) else { return [] }

        let allItems: [(listID: String, item: ReminderItem)] = [
            ("work", ReminderItem(
                id: "mock-r1",
                title: "Review PR before EOD",
                notes: nil,
                dueDate: cal.date(bySettingHour: 16, minute: 0, second: 0, of: date)!,
                listTitle: "Work",
                listColor: .blue,
                isCompleted: false
            )),
            ("home", ReminderItem(
                id: "mock-r2",
                title: "Pick up dry cleaning",
                notes: nil,
                dueDate: nil,
                listTitle: "Home",
                listColor: .orange,
                isCompleted: false
            )),
        ]

        if listIDs.isEmpty {
            return allItems.map(\.item)
        }
        return allItems.filter { listIDs.contains($0.listID) }.map(\.item)
    }
}
#endif
