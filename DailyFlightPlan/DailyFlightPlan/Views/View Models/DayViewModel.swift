//
//  DayViewModel.swift
//  DailyFlightPlan
//
import SwiftUI

@Observable @MainActor
final class DayViewModel {

    var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    var collapsedSections: Set<DaySection> = []
    private(set) var forwardNavigation: Bool = true

    // MARK: Date helpers

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// The section that contains the current clock time, or nil if not viewing today
    var currentSection: DaySection? {
        guard isToday else { return nil }
        return DaySection.containing(.now)
    }

    func goToYesterday() {
        guard let date = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        forwardNavigation = false
        selectedDate = date
    }

    func goToTomorrow() {
        guard let date = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        forwardNavigation = true
        selectedDate = date
    }

    func goToToday() {
        let today = Calendar.current.startOfDay(for: .now)
        forwardNavigation = selectedDate < today
        selectedDate = today
    }

    // MARK: Section collapse

    func isCollapsed(_ section: DaySection) -> Bool {
        collapsedSections.contains(section)
    }

    func toggleCollapsed(_ section: DaySection) {
        if collapsedSections.contains(section) {
            collapsedSections.remove(section)
        } else {
            collapsedSections.insert(section)
        }
    }

    // MARK: Missed item logic

    /// True when viewing today and the item's scheduled time has passed but it's still pending.
    /// Missed items are pulled out of their section and shown in the "any time" area with a warning style.
    func isMissed(_ item: PlanItem) -> Bool {
        guard isToday, item.status == .pending else { return false }
        if let deadline = item.deadline {
            return deadline < .now
        }
        if let section = item.daySection,
           let sectionEnd = Calendar.current.date(bySettingHour: section.endHour, minute: 59, second: 59, of: .now) {
            return sectionEnd < .now
        }
        return false
    }

    // MARK: Item grouping

    /// Items assigned to this section (excluding missed items, which fall to "any time")
    func sectionPills(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.daySection == section && !isMissed($0) }
    }

    /// Deadline items whose clock time falls within this section (excluding missed items)
    func deadlineRows(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items
            .filter { item in
                guard let deadline = item.deadline, item.daySection == nil, !isMissed(item) else { return false }
                return DaySection.containing(deadline) == section
            }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    /// Calendar events whose start time falls within this section
    func calendarEventsForSection(_ section: DaySection, from events: [CalendarEvent]) -> [CalendarEvent] {
        events.filter { DaySection.containing($0.startDate) == section }
    }

    /// Reminders with a specific due time that falls within this section
    func reminderItemsForSection(_ section: DaySection, from items: [ReminderItem]) -> [ReminderItem] {
        items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return DaySection.containing(dueDate) == section
        }
    }

    /// Reminders with no specific due time (shown in the "Any Time" area)
    func anyTimeReminderItems(from items: [ReminderItem]) -> [ReminderItem] {
        items.filter { $0.dueDate == nil }
    }

    /// Items with no section and no deadline, plus any missed items from earlier in the day
    func anyTimeItems(from items: [PlanItem]) -> [PlanItem] {
        let noTimeItems = items.filter { $0.daySection == nil && $0.deadline == nil }
        let missedItems = items.filter { isMissed($0) }
        return noTimeItems + missedItems
    }
}
