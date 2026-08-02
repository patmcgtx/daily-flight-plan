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

    // Updated each minute by startLiveClock(); drives currentSection and Past area in real time.
    private(set) var currentTime: Date = .now
    private var clockTask: Task<Void, Never>?

    // MARK: Date helpers

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// The section that contains the current clock time, or nil if not viewing today
    var currentSection: DaySection? {
        guard isToday else { return nil }
        return DaySection.containing(currentTime)
    }

    /// Sections whose time window has already ended when viewing today. Empty on other days.
    var pastSections: [DaySection] {
        guard isToday,
              let current = currentSection,
              let currentIdx = DaySection.allCases.firstIndex(of: current) else { return [] }
        return Array(DaySection.allCases.prefix(currentIdx))
    }

    /// Sections to display in the main list — all sections on non-today days, current+future on today.
    var activeSections: [DaySection] {
        guard isToday else { return DaySection.allCases }
        let past = Set(pastSections)
        return DaySection.allCases.filter { !past.contains($0) }
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

    // MARK: Live clock

    /// Starts a per-minute background tick that updates currentTime, keeping the Past area current.
func startLiveClock() {
        guard clockTask == nil else { return }
        clockTask = Task { @MainActor [weak self] in
            defer { self?.clockTask = nil }
            while !Task.isCancelled {
                let now = Date.now
                var components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: now
                )
                components.minute = (components.minute ?? 0) + 1
                components.second = 0
                components.nanosecond = 0
                let nextMinute = Calendar.current.date(from: components) ?? now.addingTimeInterval(60)
                let sleepSeconds = max(1, nextMinute.timeIntervalSince(Date.now))
                do {
                    try await Task.sleep(for: .seconds(sleepSeconds))
                } catch {
                    return
                }
                withAnimation(.spring(duration: 0.3)) {
                    self?.currentTime = .now
                }
            }
        }
    }

    // MARK: Missed item logic

    /// Combined check — used to exclude an item from its scheduled section card.
    func isMissed(_ item: PlanItem) -> Bool {
        isDeadlineMissed(item) || isSectionMissed(item)
    }

    /// Item had a specific timed deadline that has now passed → shown in "Missed".
    func isDeadlineMissed(_ item: PlanItem) -> Bool {
        guard isToday, item.status == .pending, let deadline = item.deadline else { return false }
        return deadline < currentTime
    }

    /// Item was assigned to a day section that has ended, with no specific deadline → shown in "Any Time".
    private func isSectionMissed(_ item: PlanItem) -> Bool {
        guard isToday, item.status == .pending, item.deadline == nil,
              let section = item.daySection,
              let sectionEnd = Calendar.current.date(
                  bySettingHour: section.endHour, minute: 59, second: 59, of: currentTime
              ) else { return false }
        return sectionEnd < currentTime
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

    // MARK: Projected recurring items (future dates)

    /// Recurring section-based items that should appear as a ghost preview on a future date.
    /// De-duplicated by title so the same habit only projects once even if multiple instances exist.
    /// Items already explicitly stored for that date are excluded to avoid double-showing.
    func projectedRecurringItems(for date: Date, from allItems: [PlanItem]) -> [PlanItem] {
        guard Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: .now) else { return [] }
        guard let weekday = localeWeekday(of: date) else { return [] }

        let titlesAlreadyForDate = Set(
            allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.map { $0.title }
        )

        var seenTitles = Set<String>()
        var result: [PlanItem] = []
        for item in allItems.sorted(by: { $0.date > $1.date }) {
            guard item.isRecurring,
                  item.daySection != nil,
                  item.recurringWeekdays.contains(weekday),
                  !Calendar.current.isDate(item.date, inSameDayAs: date),
                  !titlesAlreadyForDate.contains(item.title),
                  !seenTitles.contains(item.title) else { continue }
            seenTitles.insert(item.title)
            result.append(item)
        }
        return result
    }

    private func localeWeekday(of date: Date) -> Locale.Weekday? {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    // MARK: Calendar events

    /// Calendar events whose start time falls within this section
    func calendarEventsForSection(_ section: DaySection, from events: [CalendarEvent]) -> [CalendarEvent] {
        events.filter { DaySection.containing($0.startDate) == section }
    }

    /// Calendar events belonging to any past section (shown in the "Past" card at the top of today's view)
    func pastCalendarEvents(from events: [CalendarEvent]) -> [CalendarEvent] {
        let past = Set(pastSections)
        return events.filter { event in
            guard let section = DaySection.containing(event.startDate) else { return false }
            return past.contains(section)
        }
    }

    /// Timed reminders belonging to any past section (shown in the "Missed" card)
    func pastReminderItems(from items: [ReminderItem]) -> [ReminderItem] {
        let past = Set(pastSections)
        return items.filter { item in
            guard let dueDate = item.dueDate,
                  let section = DaySection.containing(dueDate) else { return false }
            return past.contains(section)
        }
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

    /// Pending items whose specific deadline has passed — shown in the "Missed" section.
    func missedDeadlineItems(from items: [PlanItem]) -> [PlanItem] {
        items.filter { isDeadlineMissed($0) }
            .sorted { ($0.deadline ?? .distantPast) < ($1.deadline ?? .distantPast) }
    }

    /// Untimed items (no section, no deadline) plus section-based items whose section has ended.
    /// Deadline-missed items are excluded — they go to the "Missed" section instead.
    func anyTimeItems(from items: [PlanItem]) -> [PlanItem] {
        let noTimeItems = items.filter { $0.daySection == nil && $0.deadline == nil }
        let sectionMissedItems = items.filter { isSectionMissed($0) }
        return noTimeItems + sectionMissedItems
    }
}
