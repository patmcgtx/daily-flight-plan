//
//  EventKitRemindersService.swift
//  DailyFlightPlan
//
import EventKit
import SwiftUI

final class EventKitRemindersService: RemindersService {

    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .notDetermined else {
            return status == .fullAccess
        }
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    func hasAccess() -> Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    func availableReminderLists() -> [ReminderListInfo] {
        store.calendars(for: .reminder).map {
            ReminderListInfo(id: $0.calendarIdentifier, title: $0.title, color: Color(cgColor: $0.cgColor))
        }
    }

    func reminders(for date: Date, listIDs: Set<String>) async -> [ReminderItem] {
        guard hasAccess() else { return [] }
        let cal = Calendar.current

        let allLists = store.calendars(for: .reminder)
        let selectedLists: [EKCalendar]? = listIDs.isEmpty ? nil : allLists.filter {
            listIDs.contains($0.calendarIdentifier)
        }

        let predicate = store.predicateForReminders(in: selectedLists)

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { ekReminders in
                let items = (ekReminders ?? [])
                    .compactMap { reminder -> ReminderItem? in
                        guard !reminder.isCompleted else { return nil }
                        guard let components = reminder.dueDateComponents,
                              let dueDate = cal.date(from: components) else { return nil }
                        guard cal.isDate(dueDate, inSameDayAs: date) else { return nil }
                        let hasTime = components.hour != nil
                        return ReminderItem(
                            id: reminder.calendarItemIdentifier,
                            title: reminder.title ?? "",
                            notes: reminder.notes,
                            dueDate: hasTime ? dueDate : nil,
                            listTitle: reminder.calendar.title,
                            listColor: Color(cgColor: reminder.calendar.cgColor),
                            isCompleted: reminder.isCompleted
                        )
                    }
                    .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                continuation.resume(returning: items)
            }
        }
    }
}
