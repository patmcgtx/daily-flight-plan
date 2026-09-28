//
//  DayViewModelTests.swift
//  DailyFlightPlanTests
//

import Testing
import SwiftUI
import Foundation
@testable import DailyFlightPlan

@Suite(.serialized)
@MainActor
struct DayViewModelTests {

    private let allWeekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    private func weekday(of date: Date) -> Locale.Weekday {
        allWeekdays[Calendar.current.component(.weekday, from: date) - 1]
    }

    private func date(hour: Int, minute: Int, daysFromNow: Int = 0) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now)!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func startDate(of section: DaySection, daysFromNow: Int = 0) -> Date {
        date(hour: section.startMinutes / 60, minute: section.startMinutes % 60, daysFromNow: daysFromNow)
    }

    /// A fixed, arbitrary instant used to inject `DayViewModel.currentTime` so clock-dependent
    /// tests don't depend on the real wall clock at the moment the test happens to run.
    private func fixedTime(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func item(
        date: Date = Calendar.current.startOfDay(for: .now),
        deadline: Date? = nil,
        daySection: DaySection? = nil,
        status: ItemStatus = .pending,
        isTemplate: Bool = false,
        recurringWeekdays: [Locale.Weekday] = []
    ) -> PlanItem {
        PlanItem(
            title: "Item",
            date: date,
            deadline: deadline,
            daySection: daySection,
            recurringWeekdays: recurringWeekdays,
            isTemplate: isTemplate,
            status: status
        )
    }

    private func event(start: Date) -> CalendarEvent {
        CalendarEvent(id: UUID().uuidString, title: "Event", startDate: start, endDate: start.addingTimeInterval(1800), calendarTitle: "Calendar", calendarColor: .blue)
    }

    private func reminder(due: Date?) -> ReminderItem {
        ReminderItem(id: UUID().uuidString, title: "Reminder", notes: nil, dueDate: due, listTitle: "List", listColor: .blue, isCompleted: false)
    }

    // MARK: isToday

    @Test("isToday reflects whether the selected date is the real current day", arguments: [
        (daysFromToday: 0, expected: true),
        (daysFromToday: -1, expected: false),
        (daysFromToday: 1, expected: false),
        (daysFromToday: -30, expected: false),
    ])
    func isToday(daysFromToday: Int, expected: Bool) {
        let viewModel = DayViewModel()
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: daysFromToday, to: .now)!
        #expect(viewModel.isToday == expected)
    }

    // MARK: Date navigation

    @Test("goToYesterday moves the selected date back one day and marks navigation backward")
    func goToYesterdayMovesBackOneDay() {
        let viewModel = DayViewModel()
        let start = viewModel.selectedDate
        viewModel.goToYesterday()
        #expect(viewModel.selectedDate == Calendar.current.date(byAdding: .day, value: -1, to: start)!)
        #expect(!viewModel.forwardNavigation)
    }

    @Test("goToTomorrow moves the selected date forward one day and marks navigation forward")
    func goToTomorrowMovesForwardOneDay() {
        let viewModel = DayViewModel()
        let start = viewModel.selectedDate
        viewModel.goToTomorrow()
        #expect(viewModel.selectedDate == Calendar.current.date(byAdding: .day, value: 1, to: start)!)
        #expect(viewModel.forwardNavigation)
    }

    @Test("goToToday returns to today's date and sets navigation direction based on where it came from", arguments: [
        (daysFromToday: -3, expectedForward: true),
        (daysFromToday: 3, expectedForward: false),
    ])
    func goToTodaySetsDirectionFromPriorDate(daysFromToday: Int, expectedForward: Bool) {
        let viewModel = DayViewModel()
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: daysFromToday, to: Calendar.current.startOfDay(for: .now))!
        viewModel.goToToday()
        #expect(viewModel.selectedDate == Calendar.current.startOfDay(for: .now))
        #expect(viewModel.forwardNavigation == expectedForward)
    }

    @Test("navigate jumps directly to the given date and sets navigation direction accordingly", arguments: [
        (daysFromToday: 5, expectedForward: true),
        (daysFromToday: -5, expectedForward: false),
    ])
    func navigateJumpsToDateAndSetsDirection(daysFromToday: Int, expectedForward: Bool) {
        let viewModel = DayViewModel()
        let target = Calendar.current.date(byAdding: .day, value: daysFromToday, to: Calendar.current.startOfDay(for: .now))!
        viewModel.navigate(to: target)
        #expect(viewModel.selectedDate == target)
        #expect(viewModel.forwardNavigation == expectedForward)
    }

    @Test("navigate does nothing when the target date is already selected")
    func navigateNoOpForSameDate() {
        let viewModel = DayViewModel()
        let target = Calendar.current.date(byAdding: .day, value: 5, to: Calendar.current.startOfDay(for: .now))!
        viewModel.navigate(to: target)
        let forwardBefore = viewModel.forwardNavigation
        viewModel.navigate(to: target)
        #expect(viewModel.selectedDate == target)
        #expect(viewModel.forwardNavigation == forwardBefore)
    }

    // MARK: Section collapse

    @Test("Toggling a section's collapsed state flips it, and toggling again restores it", arguments: DaySection.allCases)
    func toggleCollapsed(section: DaySection) {
        let viewModel = DayViewModel()
        #expect(!viewModel.isCollapsed(section))
        viewModel.toggleCollapsed(section)
        #expect(viewModel.isCollapsed(section))
        viewModel.toggleCollapsed(section)
        #expect(!viewModel.isCollapsed(section))
    }

    // MARK: Calendar events and reminders by section

    @Test("calendarEventsForSection includes only events starting within that section", arguments: DaySection.allCases)
    func calendarEventsForSection(section: DaySection) {
        let viewModel = DayViewModel()
        let matching = event(start: startDate(of: section))
        let nonMatching = DaySection.allCases.filter { $0 != section }.map { event(start: startDate(of: $0)) }
        let result = viewModel.calendarEventsForSection(section, from: [matching] + nonMatching)
        #expect(result.map(\.id) == [matching.id])
    }

    @Test("reminderItemsForSection includes only reminders due within that section", arguments: DaySection.allCases)
    func reminderItemsForSection(section: DaySection) {
        let viewModel = DayViewModel()
        let matching = reminder(due: startDate(of: section))
        let nonMatching = DaySection.allCases.filter { $0 != section }.map { reminder(due: startDate(of: $0)) }
        let untimed = reminder(due: nil)
        let result = viewModel.reminderItemsForSection(section, from: [matching] + nonMatching + [untimed])
        #expect(result.map(\.id) == [matching.id])
    }

    @Test("anyTimeReminderItems includes only reminders that have no due date")
    func anyTimeReminderItems() {
        let viewModel = DayViewModel()
        let untimed = reminder(due: nil)
        let timed = reminder(due: startDate(of: .morning))
        let result = viewModel.anyTimeReminderItems(from: [untimed, timed])
        #expect(result.map(\.id) == [untimed.id])
    }

    @Test("pastCalendarEvents includes only events in sections before the injected current time, while viewing today")
    func pastCalendarEventsIncludesEarlierSections() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        let pastEvent = event(start: startDate(of: .firstThing))
        let currentEvent = event(start: startDate(of: .morning))
        let futureEvent = event(start: startDate(of: .evening))
        let result = viewModel.pastCalendarEvents(from: [pastEvent, currentEvent, futureEvent])
        #expect(result.map(\.id) == [pastEvent.id])
    }

    @Test("pastCalendarEvents is empty when not viewing today")
    func pastCalendarEventsEmptyWhenNotToday() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let anEvent = event(start: startDate(of: .firstThing))
        #expect(viewModel.pastCalendarEvents(from: [anEvent]).isEmpty)
    }

    @Test("pastReminderItems includes only reminders due in sections before the injected current time, while viewing today")
    func pastReminderItemsIncludesEarlierSections() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        let pastReminder = reminder(due: startDate(of: .firstThing))
        let currentReminder = reminder(due: startDate(of: .morning))
        let untimedReminder = reminder(due: nil)
        let result = viewModel.pastReminderItems(from: [pastReminder, currentReminder, untimedReminder])
        #expect(result.map(\.id) == [pastReminder.id])
    }

    @Test("pastReminderItems is empty when not viewing today")
    func pastReminderItemsEmptyWhenNotToday() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let aReminder = reminder(due: startDate(of: .firstThing))
        #expect(viewModel.pastReminderItems(from: [aReminder]).isEmpty)
    }

    // MARK: anyTimeItems

    @Test("anyTimeItems includes only items with no day section and no deadline", arguments: [
        (daySection: DaySection?.none, hasDeadline: false, included: true),
        (daySection: DaySection?.some(.morning), hasDeadline: false, included: false),
        (daySection: DaySection?.none, hasDeadline: true, included: false),
        (daySection: DaySection?.some(.evening), hasDeadline: true, included: false),
    ])
    func anyTimeItems(daySection: DaySection?, hasDeadline: Bool, included: Bool) {
        let viewModel = DayViewModel()
        let subject = item(deadline: hasDeadline ? startDate(of: .morning) : nil, daySection: daySection)
        let result = viewModel.anyTimeItems(from: [subject])
        #expect(result.map(\.uuid).contains(subject.uuid) == included)
    }

    // MARK: sectionPills

    @Test("sectionPills includes only items assigned to the given section", arguments: DaySection.allCases)
    func sectionPillsGroupsBySection(section: DaySection) {
        let viewModel = DayViewModel()
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let matching = item(daySection: section)
        let nonMatching = DaySection.allCases.filter { $0 != section }.map { item(daySection: $0) }
        let result = viewModel.sectionPills(section, from: [matching] + nonMatching)
        #expect(result.map(\.uuid) == [matching.uuid])
    }

    @Test("sectionPills excludes items whose deadline has already passed today")
    func sectionPillsExcludesMissedItems() {
        let currentTime = fixedTime(hour: 12, minute: 0)
        let viewModel = DayViewModel(currentTime: currentTime)
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        let missed = item(deadline: currentTime.addingTimeInterval(-3600), daySection: .morning)
        let notMissed = item(deadline: currentTime.addingTimeInterval(3600), daySection: .morning)
        let result = viewModel.sectionPills(.morning, from: [missed, notMissed])
        #expect(result.map(\.uuid) == [notMissed.uuid])
    }

    // MARK: deadlineRows

    @Test("deadlineRows includes only unsectioned items whose deadline falls in that section, sorted earliest first")
    func deadlineRowsGroupsAndSortsBySection() {
        let viewModel = DayViewModel()
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let earlier = item(deadline: startDate(of: .evening))
        let later = item(deadline: startDate(of: .evening).addingTimeInterval(3600))
        let wrongSection = item(deadline: startDate(of: .morning))
        let hasDaySection = item(deadline: startDate(of: .evening), daySection: .evening)
        let result = viewModel.deadlineRows(.evening, from: [later, earlier, wrongSection, hasDaySection])
        #expect(result.map(\.uuid) == [earlier.uuid, later.uuid])
    }

    @Test("deadlineRows excludes items whose deadline has already passed today")
    func deadlineRowsExcludesMissedItems() {
        let currentTime = fixedTime(hour: 12, minute: 0)
        let viewModel = DayViewModel(currentTime: currentTime)
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        let missed = item(deadline: currentTime.addingTimeInterval(-3600))
        let notMissed = item(deadline: currentTime.addingTimeInterval(3600))
        let missedSection = DaySection.containing(missed.deadline!)!
        let notMissedSection = DaySection.containing(notMissed.deadline!)!
        #expect(viewModel.deadlineRows(missedSection, from: [missed]).isEmpty)
        #expect(viewModel.deadlineRows(notMissedSection, from: [notMissed]).map(\.uuid) == [notMissed.uuid])
    }

    // MARK: missedDeadlineItems

    @Test("missedDeadlineItems returns only pending items with a passed deadline, sorted earliest first")
    func missedDeadlineItems() {
        let currentTime = fixedTime(hour: 12, minute: 0)
        let viewModel = DayViewModel(currentTime: currentTime)
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        let missedEarlier = item(deadline: currentTime.addingTimeInterval(-7200), status: .pending)
        let missedLater = item(deadline: currentTime.addingTimeInterval(-3600), status: .pending)
        let notYetMissed = item(deadline: currentTime.addingTimeInterval(3600), status: .pending)
        let completedPastDeadline = item(deadline: currentTime.addingTimeInterval(-3600), status: .completed)
        let result = viewModel.missedDeadlineItems(from: [missedLater, missedEarlier, notYetMissed, completedPastDeadline])
        #expect(result.map(\.uuid) == [missedEarlier.uuid, missedLater.uuid])
    }

    // MARK: isDeadlineMissed

    @Test("isDeadlineMissed is true only for pending items with a passed deadline while viewing today", arguments: [
        (daysFromToday: 0, status: ItemStatus.pending, deadlineOffset: -3600.0, expected: true),
        (daysFromToday: 0, status: ItemStatus.pending, deadlineOffset: 3600.0, expected: false),
        (daysFromToday: 0, status: ItemStatus.completed, deadlineOffset: -3600.0, expected: false),
        (daysFromToday: 0, status: ItemStatus.canceled, deadlineOffset: -3600.0, expected: false),
        (daysFromToday: -1, status: ItemStatus.pending, deadlineOffset: -3600.0, expected: false),
    ])
    func isDeadlineMissed(daysFromToday: Int, status: ItemStatus, deadlineOffset: Double, expected: Bool) {
        let currentTime = fixedTime(hour: 12, minute: 0)
        let viewModel = DayViewModel(currentTime: currentTime)
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: daysFromToday, to: .now)!
        let subject = item(deadline: currentTime.addingTimeInterval(deadlineOffset), status: status)
        #expect(viewModel.isDeadlineMissed(subject) == expected)
    }

    @Test("isDeadlineMissed is false for items without a deadline")
    func isDeadlineMissedWithNoDeadline() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 12, minute: 0))
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        let subject = item(deadline: nil, status: .pending)
        #expect(!viewModel.isDeadlineMissed(subject))
    }

    // MARK: projectedRecurringItems

    @Test("projectedRecurringItems returns nothing for today or past dates", arguments: [-30, -1, 0])
    func projectedRecurringItemsPastOrTodayGuard(daysFromToday: Int) {
        let viewModel = DayViewModel()
        let target = Calendar.current.date(byAdding: .day, value: daysFromToday, to: .now)!
        let template = item(daySection: .morning, isTemplate: true, recurringWeekdays: allWeekdays)
        #expect(viewModel.projectedRecurringItems(for: target, from: [template]).isEmpty)
    }

    @Test("projectedRecurringItems includes future templates scheduled for that weekday and section")
    func projectedRecurringItemsIncludesMatchingFutureTemplate() {
        let viewModel = DayViewModel()
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let matchingWeekday = weekday(of: futureDate)
        let otherWeekday: Locale.Weekday = matchingWeekday == .sunday ? .monday : .sunday
        let matchingTemplate = item(daySection: .morning, isTemplate: true, recurringWeekdays: [matchingWeekday])
        let wrongWeekday = item(daySection: .morning, isTemplate: true, recurringWeekdays: [otherWeekday])
        let notATemplate = item(daySection: .morning, isTemplate: false, recurringWeekdays: [matchingWeekday])
        let noSection = item(daySection: nil, isTemplate: true, recurringWeekdays: [matchingWeekday])
        let result = viewModel.projectedRecurringItems(for: futureDate, from: [matchingTemplate, wrongWeekday, notATemplate, noSection])
        #expect(result.map(\.uuid) == [matchingTemplate.uuid])
    }

    @Test("projectedRecurringItems excludes templates that already have a materialized instance for that date")
    func projectedRecurringItemsExcludesTemplatesWithExistingInstance() {
        let viewModel = DayViewModel()
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let matchingWeekday = weekday(of: futureDate)
        let template = item(daySection: .morning, isTemplate: true, recurringWeekdays: [matchingWeekday])
        let instance = item(date: futureDate)
        template.instances = [instance]
        let result = viewModel.projectedRecurringItems(for: futureDate, from: [template])
        #expect(result.isEmpty)
    }

    // MARK: currentSection

    @Test("currentSection matches the section containing the injected current time only while viewing today")
    func currentSectionRespectsIsToday() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        #expect(viewModel.currentSection == .morning)
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        #expect(viewModel.currentSection == nil)
    }

    // MARK: pastSections

    @Test("pastSections returns every section before the one containing the injected current time, while viewing today")
    func pastSectionsBeforeCurrentToday() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        #expect(viewModel.pastSections == [.firstThing])
    }

    @Test("pastSections is empty when not viewing today")
    func pastSectionsEmptyWhenNotToday() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        #expect(viewModel.pastSections.isEmpty)
    }

    // MARK: applyAutoCollapse

    @Test("applyAutoCollapse collapses every section except the one containing the injected current time")
    func applyAutoCollapseWhenToday() {
        let viewModel = DayViewModel(currentTime: fixedTime(hour: 8, minute: 0))
        viewModel.selectedDate = Calendar.current.startOfDay(for: .now)
        viewModel.applyAutoCollapse()
        let expectedCollapsed = Set(DaySection.allCases.filter { $0 != .morning })
        #expect(viewModel.collapsedSections == expectedCollapsed)
    }

    @Test("applyAutoCollapse clears all collapsed sections when not viewing today")
    func applyAutoCollapseWhenNotToday() {
        let viewModel = DayViewModel()
        viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        viewModel.toggleCollapsed(.morning)
        viewModel.applyAutoCollapse()
        #expect(viewModel.collapsedSections.isEmpty)
    }
}
