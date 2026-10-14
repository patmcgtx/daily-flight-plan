//
//  DayPlanMarkdownExporterTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

@MainActor
struct DayPlanMarkdownExporterTests {

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
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
        status: ItemStatus = .pending,
        categories: [PlanCategory] = [],
        isTemplate: Bool = false,
        template: PlanItem? = nil
    ) -> PlanItem {
        let result = PlanItem(
            title: title, notes: notes, isFlagged: isFlagged,
            deadline: deadline, daySection: daySection,
            isTemplate: isTemplate, status: status, categories: categories
        )
        result.template = template
        return result
    }

    @Test("export(items:date:) with no items renders the date header and an empty-state placeholder")
    func exportWithNoItems() {
        let day = date(hour: 0, minute: 0)
        let markdown = DayPlanMarkdownExporter.export(items: [], date: day)

        #expect(markdown.hasPrefix("# Day Plan Export\n"))
        #expect(markdown.contains("_No items yet._"))
    }

    @Test("Each item's completion status renders as the expected label", arguments: [
        (ItemStatus.pending, "- Status: Pending"),
        (ItemStatus.completed, "- Status: Completed"),
        (ItemStatus.canceled, "- Status: Canceled"),
    ])
    func exportStatusLabel(status: ItemStatus, expectedLine: String) {
        let subject = item(daySection: .morning, status: status)
        let markdown = DayPlanMarkdownExporter.export(items: [subject], date: .now)
        #expect(markdown.contains(expectedLine))
    }

    @Test(
        "Routine field reflects isRecurring — true for templates and for instances linked to a template, false for one-off items",
        arguments: [
            (isTemplate: false, hasTemplateLink: false, expected: "- Routine: No"),
            (isTemplate: true, hasTemplateLink: false, expected: "- Routine: Yes"),
            (isTemplate: false, hasTemplateLink: true, expected: "- Routine: Yes"),
        ]
    )
    func exportRoutineField(isTemplate: Bool, hasTemplateLink: Bool, expected: String) {
        let linkedTemplate = hasTemplateLink ? PlanItem(title: "Parent Routine", isTemplate: true) : nil
        let subject = item(daySection: .morning, isTemplate: isTemplate, template: linkedTemplate)
        let markdown = DayPlanMarkdownExporter.export(items: [subject], date: .now)
        #expect(markdown.contains(expected))
    }

    @Test("Flagged status, categories, and notes render their expected field values")
    func exportFieldValuesWhenPresent() {
        let subject = item(
            title: "Walk the dog", notes: "Bring poop bags", isFlagged: true, daySection: .evening,
            categories: [PlanCategory(name: "Pets"), PlanCategory(name: "Exercise")]
        )
        let markdown = DayPlanMarkdownExporter.export(items: [subject], date: .now)

        #expect(markdown.contains("- Flagged: Yes"))
        #expect(markdown.contains("- Categories: Exercise, Pets"))
        #expect(markdown.contains("- Notes: Bring poop bags"))
    }

    @Test("Empty categories render as None and empty notes omit the Notes line entirely")
    func exportFieldValuesWhenAbsent() {
        let subject = item(daySection: .evening)
        let markdown = DayPlanMarkdownExporter.export(items: [subject], date: .now)

        #expect(markdown.contains("- Categories: None"))
        #expect(!markdown.contains("- Notes:"))
    }

    @Test("An item with no day section and no deadline is grouped under the Open section")
    func exportItemWithoutSectionOrDeadlineFallsIntoOpen() {
        let subject = item(daySection: nil)
        let markdown = DayPlanMarkdownExporter.export(items: [subject], date: .now)

        #expect(markdown.contains("## Open"))
    }

    @Test("An item with only a deadline resolves its day-section header from the deadline's time")
    func exportDeadlineOnlyItemResolvesSectionFromTime() {
        let subject = item(deadline: date(hour: 8, minute: 0))
        let markdown = DayPlanMarkdownExporter.export(items: [subject], date: .now)

        #expect(markdown.contains("## Morning"))
    }

    @Test("Items within the same day section are sorted by deadline time, then alphabetically")
    func exportSectionItemsSortByDeadlineThenTitle() {
        let zebra = item(title: "Zebra Task", daySection: .morning)
        let apple = item(title: "Apple Task", daySection: .morning)
        let timed = item(title: "Timed Task", deadline: date(hour: 8, minute: 0), daySection: .morning)
        let markdown = DayPlanMarkdownExporter.export(items: [zebra, apple, timed], date: .now)

        let timedRange = markdown.range(of: "### Timed Task")!
        let appleRange = markdown.range(of: "### Apple Task")!
        let zebraRange = markdown.range(of: "### Zebra Task")!
        #expect(timedRange.lowerBound < appleRange.lowerBound)
        #expect(appleRange.lowerBound < zebraRange.lowerBound)
    }

    @Test("Canceled items are still included in the export alongside pending and completed items")
    func exportIncludesCanceledItems() {
        let canceled = item(title: "Canceled Task", daySection: .morning, status: .canceled)
        let pending = item(title: "Pending Task", daySection: .morning, status: .pending)
        let markdown = DayPlanMarkdownExporter.export(items: [canceled, pending], date: .now)

        #expect(markdown.contains("### Canceled Task"))
        #expect(markdown.contains("- Status: Canceled"))
        #expect(markdown.contains("### Pending Task"))
    }
}
