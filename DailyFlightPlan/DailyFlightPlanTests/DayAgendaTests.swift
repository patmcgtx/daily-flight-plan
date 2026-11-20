//
//  DayAgendaTests.swift
//  DailyFlightPlanTests
//

import Testing
import SwiftUI
import Foundation
@testable import DailyFlightPlan

@Suite(.serialized)
@MainActor
struct DayAgendaTests {

    /// Where an entry is expected to land.
    enum Place {
        case upcoming, passed, section
    }

    /// Today at the given time. "Now" for these tests is 2:00 PM, which falls in Afternoon
    /// (Morning and Midday have ended).
    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now)!
    }

    private func viewModel(now: Date? = nil, viewingToday: Bool = true) -> DayViewModel {
        let viewModel = DayViewModel(currentTime: now ?? time(14))
        viewModel.selectedDate = viewingToday
            ? Calendar.current.startOfDay(for: .now)
            : Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))!
        return viewModel
    }

    private func item(
        deadline: Date? = nil,
        daySection: DaySection? = nil,
        status: ItemStatus = .pending,
        isRecurring: Bool = false
    ) -> PlanItem {
        let item = PlanItem(
            title: "Item", deadline: deadline, daySection: daySection, status: status
        )
        if isRecurring {
            // A resolved template link is what marks an instance as recurring.
            item.template = PlanItem(title: "Template", isTemplate: true)
        }
        return item
    }

    private func event(start: Date, minutes: Int = 30) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString, title: "Event", startDate: start,
            endDate: start.addingTimeInterval(Double(minutes) * 60),
            calendarTitle: "Calendar", calendarColor: .blue
        )
    }

    private func reminder(due: Date?, completed: Bool = false) -> ReminderItem {
        ReminderItem(
            id: UUID().uuidString, title: "Reminder", notes: nil, dueDate: due,
            listTitle: "List", listColor: .blue, isCompleted: completed
        )
    }

    /// Where `agenda` put the plan item: Up Next, Passed, a day section, or nowhere (nil).
    private func place(of item: PlanItem, in agenda: DayAgenda) -> Place? {
        if agenda.upcoming.contains(where: { $0.id == DayEntry.planItem(item).id }) { return .upcoming }
        if agenda.passed.contains(where: { $0.id == DayEntry.planItem(item).id }) { return .passed }
        if agenda.sectionItems.contains(where: { $0.uuid == item.uuid }) { return .section }
        return nil
    }

    // MARK: Plan items with a deadline

    @Test("A timed plan item is upcoming before its deadline; after it, passed if pending and back in its section if completed", arguments: [
        (deadlineHour: 15, status: ItemStatus.pending, expected: Place.upcoming),
        (deadlineHour: 15, status: ItemStatus.completed, expected: Place.upcoming),
        (deadlineHour: 9, status: ItemStatus.pending, expected: Place.passed),
        (deadlineHour: 9, status: ItemStatus.completed, expected: Place.section),
    ])
    func timedPlanItem(deadlineHour: Int, status: ItemStatus, expected: Place) {
        let subject = item(deadline: time(deadlineHour), status: status)
        let agenda = viewModel().agenda(items: [subject], events: [], reminders: [])
        #expect(place(of: subject, in: agenda) == expected)
    }

    @Test("A canceled plan item is never upcoming or passed, only left in its section", arguments: [9, 15])
    func canceledItemsStayInSection(deadlineHour: Int) {
        let canceled = item(deadline: time(deadlineHour), status: .canceled)
        let agenda = viewModel().agenda(items: [canceled], events: [], reminders: [])
        #expect(place(of: canceled, in: agenda) == .section)
    }

    @Test("A timed recurring item still counts as a commitment")
    func timedRecurringItemIsIncluded() {
        let routine = item(deadline: time(9), isRecurring: true)
        let agenda = viewModel().agenda(items: [routine], events: [], reminders: [])
        #expect(place(of: routine, in: agenda) == .passed)
    }

    // MARK: Untimed items whose section ended

    @Test("An untimed pending item is passed only once its section has ended", arguments: [
        (section: DaySection.firstThing, expected: Place.passed),
        (section: DaySection.morning, expected: Place.passed),
        (section: DaySection.midday, expected: Place.passed),
        (section: DaySection.afternoon, expected: Place.section),
        (section: DaySection.evening, expected: Place.section),
        (section: DaySection.bedtime, expected: Place.section),
    ])
    func sectionMissed(section: DaySection, expected: Place) {
        let subject = item(daySection: section)
        let agenda = viewModel().agenda(items: [subject], events: [], reminders: [])
        #expect(place(of: subject, in: agenda) == expected)
    }

    @Test("An untimed recurring (Maintenance) item is passed once its section ends, like any other item")
    func recurringSectionMissed() {
        let routine = item(daySection: .morning, isRecurring: true)
        let agenda = viewModel().agenda(items: [routine], events: [], reminders: [])
        #expect(place(of: routine, in: agenda) == .passed)
    }

    @Test("Completed untimed items stay in their ended section rather than going to Passed")
    func completedSectionItemsStay() {
        let done = item(daySection: .morning, status: .completed)
        let agenda = viewModel().agenda(items: [done], events: [], reminders: [])
        #expect(place(of: done, in: agenda) == .section)
    }

    @Test("sectionItems keeps whatever stays in a section and drops upcoming timed items and passed ones")
    func sectionItemsExcludesAgendaItems() {
        let viewModel = viewModel()
        let upcomingTimed = item(deadline: time(16), daySection: .afternoon)
        let passedTimed = item(deadline: time(9), daySection: .morning)
        let passedUntimed = item(daySection: .morning)
        let passedRoutine = item(daySection: .morning, isRecurring: true)
        let currentInSection = item(daySection: .afternoon)
        let completedTimedPast = item(deadline: time(9), daySection: .morning, status: .completed)
        let completedInEndedSection = item(daySection: .morning, status: .completed)
        let open = item()
        let result = viewModel.sectionItems(from: [
            upcomingTimed, passedTimed, passedUntimed, passedRoutine, currentInSection,
            completedTimedPast, completedInEndedSection, open,
        ])
        #expect(Set(result.map(\.uuid)) == Set(
            [currentInSection, completedTimedPast, completedInEndedSection, open].map(\.uuid)
        ))
    }

    // MARK: Calendar events

    @Test("An event is upcoming until it ends, so one in progress still counts; an ended one is dropped and shown nowhere", arguments: [
        (startHour: 15, startMinute: 0, minutes: 30, expectedUpcoming: true),
        (startHour: 13, startMinute: 30, minutes: 60, expectedUpcoming: true),
        (startHour: 9, startMinute: 0, minutes: 30, expectedUpcoming: false),
        (startHour: 13, startMinute: 0, minutes: 60, expectedUpcoming: false),
    ])
    func eventPlacement(startHour: Int, startMinute: Int, minutes: Int, expectedUpcoming: Bool) {
        let subject = event(start: time(startHour, startMinute), minutes: minutes)
        let viewModel = viewModel()
        let agenda = viewModel.agenda(items: [], events: [subject], reminders: [])
        #expect(agenda.upcoming.map(\.id) == (expectedUpcoming ? [DayEntry.calendarEvent(subject).id] : []))
        #expect(agenda.passed.isEmpty)
        // An ended event must not keep any segment alive, either.
        #expect(DaySection.allCases.allSatisfy { !viewModel.hasContent($0, in: agenda) })
    }

    // MARK: Reminders

    @Test("A timed reminder is upcoming before its due time and in Passed after it, whether open or completed", arguments: [
        (dueHour: 15, completed: false, expected: Place.upcoming),
        (dueHour: 15, completed: true, expected: Place.upcoming),
        (dueHour: 9, completed: false, expected: Place.passed),
        (dueHour: 9, completed: true, expected: Place.passed),
    ])
    func timedReminder(dueHour: Int, completed: Bool, expected: Place) {
        let subject = reminder(due: time(dueHour), completed: completed)
        let viewModel = viewModel()
        let agenda = viewModel.agenda(items: [], events: [], reminders: [subject])
        let id = DayEntry.reminder(subject).id
        #expect(agenda.upcoming.map(\.id) == (expected == .upcoming ? [id] : []))
        #expect(agenda.passed.map(\.id) == (expected == .passed ? [id] : []))
        // Reminders never keep a segment alive: they live in Up Next or Passed.
        #expect(DaySection.allCases.allSatisfy { !viewModel.hasContent($0, in: agenda) })
    }

    @Test("A reminder with no due time is left out of every list")
    func untimedReminderIsLeftOut() {
        let agenda = viewModel().agenda(items: [], events: [], reminders: [reminder(due: nil)])
        #expect(agenda.upcoming.isEmpty)
        #expect(agenda.passed.isEmpty)
    }

    // MARK: Ordering and other days

    @Test("Upcoming entries from every source are interleaved soonest first")
    func upcomingIsSortedAcrossSources() {
        let late = item(deadline: time(18))
        let middle = event(start: time(16))
        let early = reminder(due: time(15))
        let agenda = viewModel().agenda(items: [late], events: [middle], reminders: [early])
        #expect(agenda.upcoming.map(\.id) == [
            DayEntry.reminder(early).id, DayEntry.calendarEvent(middle).id, DayEntry.planItem(late).id,
        ])
    }

    @Test("Passed entries are oldest first, using the section's end for untimed items")
    func passedIsChronological() {
        let timedLater = item(deadline: time(12, 30))
        let untimedMorning = item(daySection: .morning)
        let overdueReminder = reminder(due: time(8))
        let agenda = viewModel().agenda(items: [timedLater, untimedMorning], events: [], reminders: [overdueReminder])
        #expect(agenda.passed.map(\.id) == [
            DayEntry.reminder(overdueReminder).id,   // 8:00
            DayEntry.planItem(untimedMorning).id,    // morning ends 10:59
            DayEntry.planItem(timedLater).id,        // 12:30
        ])
    }

    @Test("passedRuns keeps the list oldest first, grouping only neighboring plan items into one pill run")
    func passedRunsPreserveOrder() {
        let viewModel = viewModel()
        let earlyReminder = reminder(due: time(8))
        let firstItem = item(deadline: time(9))
        let secondItem = item(deadline: time(10))
        let lateReminder = reminder(due: time(11))
        let lastItem = item(deadline: time(12))
        let agenda = viewModel.agenda(
            items: [lastItem, secondItem, firstItem], events: [], reminders: [lateReminder, earlyReminder]
        )
        let runs = viewModel.passedRuns(from: agenda.passed)
        #expect(runs.map(\.id) == [
            PassedRun.reminder(earlyReminder).id,
            PassedRun.pills([firstItem, secondItem]).id,
            PassedRun.reminder(lateReminder).id,
            PassedRun.pills([lastItem]).id,
        ])
    }

    @Test("passedRuns is empty for an empty list and skips calendar events")
    func passedRunsEdgeCases() {
        let viewModel = viewModel()
        #expect(viewModel.passedRuns(from: []).isEmpty)
        #expect(viewModel.passedRuns(from: [.calendarEvent(event(start: time(9)))]).isEmpty)
    }

    @Test("On a day other than today every timed entry is upcoming and nothing is passed")
    func otherDaysHaveNoPassed() {
        let viewModel = viewModel(viewingToday: false)
        let timed = item(deadline: time(9))
        let pastEvent = event(start: time(8))
        let overdue = reminder(due: time(7))
        let sectioned = item(daySection: .morning)
        let agenda = viewModel.agenda(items: [timed, sectioned], events: [pastEvent], reminders: [overdue])
        #expect(agenda.passed.isEmpty)
        #expect(agenda.upcoming.count == 3)
        #expect(agenda.sectionItems.map(\.uuid) == [sectioned.uuid])
    }

    // MARK: Section boundary

    @Test("An untimed First Thing item is passed from 7:30 AM, when Morning starts", arguments: [
        (hour: 7, minute: 29, expected: Place.section),
        (hour: 7, minute: 30, expected: Place.passed),
        (hour: 7, minute: 45, expected: Place.passed),
    ])
    func firstThingEndsWhenMorningStarts(hour: Int, minute: Int, expected: Place) {
        let subject = item(daySection: .firstThing)
        let agenda = viewModel(now: time(hour, minute)).agenda(items: [subject], events: [], reminders: [])
        #expect(place(of: subject, in: agenda) == expected)
    }

    // MARK: Drop rules

    @Test("canMove refuses an open item dropped on an ended segment, and nothing else", arguments: [
        (status: ItemStatus.pending, target: DaySection?.some(.morning), expected: false),
        (status: ItemStatus.pending, target: DaySection?.some(.midday), expected: false),
        (status: ItemStatus.pending, target: DaySection?.some(.afternoon), expected: true),   // current
        (status: ItemStatus.pending, target: DaySection?.some(.evening), expected: true),     // later
        (status: ItemStatus.pending, target: DaySection?.none, expected: true),               // Open
        (status: ItemStatus.completed, target: DaySection?.some(.morning), expected: true),   // done stays
    ])
    func canMove(status: ItemStatus, target: DaySection?, expected: Bool) {
        let subject = item(daySection: .evening, status: status)
        #expect(viewModel().canMove(subject, to: target) == expected)
    }

    @Test("canMove accepts any drop when not viewing today, since no segment has ended")
    func canMoveOnOtherDays() {
        let subject = item(daySection: .evening)
        #expect(viewModel(viewingToday: false).canMove(subject, to: .morning))
    }

    // MARK: Segment content

    @Test("hasContent is true only for a segment holding an untimed plan item or a completed one that came due there; ended events and reminders don't count", arguments: [
        (section: DaySection.firstThing, expected: false),  // only a completed reminder due 5:00
        (section: DaySection.morning, expected: true),      // completed item due 9:00
        (section: DaySection.midday, expected: false),      // only an ended event at 12:00
        (section: DaySection.afternoon, expected: true),    // untimed item
        (section: DaySection.evening, expected: false),
        (section: DaySection.bedtime, expected: false),
    ])
    func hasContentPerSection(section: DaySection, expected: Bool) {
        let viewModel = viewModel()
        let agenda = viewModel.agenda(
            items: [item(daySection: .afternoon), item(deadline: time(9), status: .completed)],
            events: [event(start: time(12))],
            reminders: [reminder(due: time(5), completed: true)]
        )
        #expect(viewModel.hasContent(section, in: agenda) == expected)
    }

    @Test("A past segment whose open items moved to Passed has no content left")
    func hasContentIgnoresPassedItems() {
        let viewModel = viewModel()
        let agenda = viewModel.agenda(
            items: [item(daySection: .morning), item(deadline: time(9))], events: [], reminders: []
        )
        #expect(agenda.passed.count == 2)
        #expect(!viewModel.hasContent(.morning, in: agenda))
    }

    // MARK: Passed summary prompt

    @Test("passedSummaryParts follows the oldest-first order across plan items and reminders and labels untimed items with their section end")
    func passedSummaryPartsFollowChronology() {
        let viewModel = viewModel()
        let timed = PlanItem(title: "Call Sam", deadline: time(9, 30))
        let untimed = PlanItem(title: "Water plants", daySection: .morning)   // morning ends 10:59
        let due = ReminderItem(
            id: "r", title: "Pay rent", notes: nil, dueDate: time(8), listTitle: "List",
            listColor: .blue, isCompleted: false
        )
        let agenda = viewModel.agenda(items: [untimed, timed], events: [], reminders: [due])
        #expect(viewModel.passedSummaryParts(entries: agenda.passed) == [
            "Pay rent at \(time(8).formatted(.dateTime.hour().minute()))",
            "Call Sam at \(time(9, 30).formatted(.dateTime.hour().minute()))",
            "Water plants at \(time(10, 59).formatted(.dateTime.hour().minute()))",
        ])
    }

    @Test("passedSummaryParts describes what's left, so a completed reminder in Passed is left out of the prompt")
    func passedSummaryPartsSkipCompletedReminders() {
        let viewModel = viewModel()
        let open = reminder(due: time(8))
        let done = reminder(due: time(7), completed: true)
        let agenda = viewModel.agenda(items: [], events: [], reminders: [open, done])
        #expect(agenda.passed.count == 2)
        #expect(viewModel.passedSummaryParts(entries: agenda.passed).count == 1)
    }

    @Test("passedSummaryParts caps the prompt at the eight oldest entries, so older reminders aren't crowded out by newer plan items")
    func passedSummaryPartsKeepOldestWhenCapped() {
        let viewModel = viewModel()
        let oldReminder = reminder(due: time(5))
        let manyItems = (0..<12).map { PlanItem(title: "Item \($0)", deadline: time(9, $0)) }
        let agenda = viewModel.agenda(items: manyItems, events: [], reminders: [oldReminder])
        let parts = viewModel.passedSummaryParts(entries: agenda.passed)
        #expect(parts.count == 8)
        #expect(parts.first?.hasPrefix("Reminder") == true)
    }

    @Test("The Passed summary signature changes when an untimed item moves between ended segments, even though its title, status and deadline don't")
    func passedSummarySignatureTracksSegment() {
        let viewModel = viewModel()
        let subject = item(daySection: .morning)
        func passedSignature() -> String {
            viewModel.passedSummarySignature(entries: viewModel.agenda(items: [subject], events: [], reminders: []).passed)
        }
        let plainBefore = viewModel.contentSignature(items: [subject], events: [], reminders: [])
        let passedBefore = passedSignature()

        subject.daySection = .midday   // still ended at 2 PM, so it stays in Passed

        // The plain signature can't see the move, which is the gap the Passed one closes.
        #expect(viewModel.contentSignature(items: [subject], events: [], reminders: []) == plainBefore)
        #expect(passedSignature() != passedBefore)
    }

    @Test("The Passed summary signature is stable for unchanged contents and changes when the contents do")
    func passedSummarySignatureStability() {
        let viewModel = viewModel()
        let first = item(deadline: time(9))
        let second = reminder(due: time(8))
        let entries = viewModel.agenda(items: [first], events: [], reminders: [second]).passed
        #expect(viewModel.passedSummarySignature(entries: entries) == viewModel.passedSummarySignature(entries: entries))
        #expect(viewModel.passedSummarySignature(entries: entries) != viewModel.passedSummarySignature(entries: []))
    }

    // MARK: Countdown

    @Test("countdownLabel reads 'now' once started and rounds partial minutes up", arguments: [
        (minutesAhead: -10, expected: "now"),
        (minutesAhead: 0, expected: "now"),
        (minutesAhead: 1, expected: "in 1 min"),
        (minutesAhead: 42, expected: "in 42 min"),
        (minutesAhead: 60, expected: "in 1h"),
        (minutesAhead: 80, expected: "in 1h 20m"),
    ])
    func countdownLabel(minutesAhead: Int, expected: String) {
        let now = time(14)
        let subject = reminder(due: now.addingTimeInterval(Double(minutesAhead) * 60))
        #expect(viewModel(now: now).countdownLabel(for: .reminder(subject)) == expected)
    }
}
