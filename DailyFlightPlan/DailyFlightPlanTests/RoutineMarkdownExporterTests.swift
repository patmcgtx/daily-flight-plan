//
//  RoutineMarkdownExporterTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

@MainActor
struct RoutineMarkdownExporterTests {

    private func date(hour: Int, minute: Int) -> Date {
        date(year: 2026, month: 6, day: 15, hour: hour, minute: minute)
    }

    /// Templates normalize their deadline onto whichever calendar day they were created/edited
    /// on, so cross-day sort-order tests need deadlines on different days, not just different times.
    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func item(
        title: String = "Item",
        notes: String = "",
        isFlagged: Bool = false,
        deadline: Date? = nil,
        daySection: DaySection? = nil,
        recurringWeekdays: [Locale.Weekday] = [],
        categories: [PlanCategory] = []
    ) -> PlanItem {
        PlanItem(
            title: title, notes: notes, isFlagged: isFlagged,
            deadline: deadline, daySection: daySection,
            recurringWeekdays: recurringWeekdays, isTemplate: true,
            categories: categories
        )
    }

    @Test("export(templates:) with no templates renders only the header and an empty-state placeholder")
    func exportWithNoTemplates() {
        let markdown = RoutineMarkdownExporter.export(templates: [])
        #expect(markdown.hasPrefix("# Routine Export\n"))
        #expect(markdown.contains("_No routine items yet._"))
        #expect(!markdown.contains("##"))
    }

    @Test("A single Every Day/Morning item renders under nested schedule and segment headers, with no redundant Segment field")
    func exportSingleItemNestsScheduleAndSegment() {
        let template = item(
            title: "Take Vitamins", daySection: .morning,
            recurringWeekdays: Array(RoutineMarkdownExporter.everyDay),
            categories: [PlanCategory(name: "Health")]
        )
        let markdown = RoutineMarkdownExporter.export(templates: [template])

        #expect(markdown.contains("## Every Day"))
        #expect(markdown.contains("### Morning"))
        #expect(markdown.contains("#### Take Vitamins"))
        #expect(markdown.contains("- Flagged: No"))
        #expect(markdown.contains("- Categories: Health"))
        #expect(!markdown.contains("- Segment:"))
        #expect(!markdown.contains("- Days:"))
    }

    @Test("Flagged status, categories, and notes render their expected field values")
    func exportFieldValuesWhenPresent() {
        let template = item(
            title: "Walk the dog", notes: "Bring poop bags", isFlagged: true,
            recurringWeekdays: Array(RoutineMarkdownExporter.weekdays),
            categories: [PlanCategory(name: "Pets"), PlanCategory(name: "Exercise")]
        )
        let markdown = RoutineMarkdownExporter.export(templates: [template])

        #expect(markdown.contains("- Flagged: Yes"))
        #expect(markdown.contains("- Categories: Exercise, Pets"))
        #expect(markdown.contains("- Notes: Bring poop bags"))
    }

    @Test("Empty categories render as None and empty notes omit the Notes line entirely")
    func exportFieldValuesWhenAbsent() {
        let template = item(recurringWeekdays: Array(RoutineMarkdownExporter.weekends))
        let markdown = RoutineMarkdownExporter.export(templates: [template])

        #expect(markdown.contains("- Categories: None"))
        #expect(!markdown.contains("- Notes:"))
    }

    @Test("An item with no day section and no deadline is grouped under the Open subsection")
    func exportItemWithoutSectionOrDeadlineFallsIntoOpen() {
        let template = item(daySection: nil, recurringWeekdays: Array(RoutineMarkdownExporter.weekdays))
        let markdown = RoutineMarkdownExporter.export(templates: [template])

        #expect(markdown.contains("## Weekdays"))
        #expect(markdown.contains("### Open"))
    }

    @Test("An item with only a deadline resolves its day-segment subsection from the deadline's time")
    func exportDeadlineOnlyItemResolvesSegmentFromTime() {
        let template = item(deadline: date(hour: 8, minute: 0), recurringWeekdays: Array(RoutineMarkdownExporter.everyDay))
        let markdown = RoutineMarkdownExporter.export(templates: [template])

        #expect(markdown.contains("### Morning"))
    }

    @Test("Custom (non-preset) weekday patterns are named by weekday abbreviation and ordered by weekday index")
    func exportCustomPatternsAreNamedAndOrderedByWeekday() {
        let tueThu = item(title: "Tue Thu Item", recurringWeekdays: [.tuesday, .thursday])
        let monWed = item(title: "Mon Wed Item", recurringWeekdays: [.monday, .wednesday])
        let markdown = RoutineMarkdownExporter.export(templates: [tueThu, monWed])

        #expect(markdown.contains("## Mon · Wed"))
        #expect(markdown.contains("## Tue · Thu"))
        let monWedRange = markdown.range(of: "## Mon · Wed")!
        let tueThuRange = markdown.range(of: "## Tue · Thu")!
        #expect(monWedRange.lowerBound < tueThuRange.lowerBound)
    }

    @Test("Items within the same day segment are sorted by deadline time, then alphabetically")
    func exportSegmentItemsSortByDeadlineThenTitle() {
        let everyDay = Array(RoutineMarkdownExporter.everyDay)
        let zebra = item(title: "Zebra Task", daySection: .morning, recurringWeekdays: everyDay)
        let apple = item(title: "Apple Task", daySection: .morning, recurringWeekdays: everyDay)
        let timed = item(
            title: "Timed Task", deadline: date(hour: 8, minute: 0),
            daySection: .morning, recurringWeekdays: everyDay
        )
        let markdown = RoutineMarkdownExporter.export(templates: [zebra, apple, timed])

        let timedRange = markdown.range(of: "#### Timed Task")!
        let appleRange = markdown.range(of: "#### Apple Task")!
        let zebraRange = markdown.range(of: "#### Zebra Task")!
        #expect(timedRange.lowerBound < appleRange.lowerBound)
        #expect(appleRange.lowerBound < zebraRange.lowerBound)
    }

    @Test("Items sharing the exact same deadline break the tie alphabetically by title")
    func exportSegmentItemsWithEqualDeadlinesSortByTitle() {
        let everyDay = Array(RoutineMarkdownExporter.everyDay)
        let sharedDeadline = date(hour: 8, minute: 0)
        let zebra = item(title: "Zebra Task", deadline: sharedDeadline, daySection: .morning, recurringWeekdays: everyDay)
        let apple = item(title: "Apple Task", deadline: sharedDeadline, daySection: .morning, recurringWeekdays: everyDay)
        let markdown = RoutineMarkdownExporter.export(templates: [zebra, apple])

        let appleRange = markdown.range(of: "#### Apple Task")!
        let zebraRange = markdown.range(of: "#### Zebra Task")!
        #expect(appleRange.lowerBound < zebraRange.lowerBound)
    }

    @Test("Templates sort by clock time, not by the calendar day their deadline happens to be normalized onto")
    func exportSegmentItemsSortByClockTimeAcrossDifferentDeadlineDays() {
        let everyDay = Array(RoutineMarkdownExporter.everyDay)
        // Earlier calendar date, later clock time — a naive full-Date comparison would sort this first.
        let earlyDateLateTime = item(
            title: "Early Date Late Time", deadline: date(year: 2026, month: 1, day: 1, hour: 9, minute: 0),
            daySection: .morning, recurringWeekdays: everyDay
        )
        // Later calendar date, earlier clock time — should actually sort first.
        let lateDateEarlyTime = item(
            title: "Late Date Early Time", deadline: date(year: 2026, month: 6, day: 15, hour: 8, minute: 0),
            daySection: .morning, recurringWeekdays: everyDay
        )
        let markdown = RoutineMarkdownExporter.export(templates: [earlyDateLateTime, lateDateEarlyTime])

        let earlyDateRange = markdown.range(of: "#### Early Date Late Time")!
        let lateDateRange = markdown.range(of: "#### Late Date Early Time")!
        #expect(lateDateRange.lowerBound < earlyDateRange.lowerBound)
    }

    @Test("A schedule with no matching templates is omitted from the export entirely")
    func exportOmitsEmptySchedules() {
        let template = item(recurringWeekdays: Array(RoutineMarkdownExporter.weekdays))
        let markdown = RoutineMarkdownExporter.export(templates: [template])

        #expect(markdown.contains("## Weekdays"))
        #expect(!markdown.contains("## Every Day"))
        #expect(!markdown.contains("## Weekends"))
    }
}
