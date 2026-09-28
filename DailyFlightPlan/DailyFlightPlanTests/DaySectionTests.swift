//
//  DaySectionTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

struct DaySectionTests {

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @Test("Sections are ordered chronologically through the day")
    func allCasesAreInChronologicalOrder() {
        let startMinutes = DaySection.allCases.map(\.startMinutes)
        #expect(startMinutes == startMinutes.sorted())
    }

    @Test("Display name matches the expected human-readable section name", arguments: [
        (DaySection.firstThing, "First Thing"),
        (DaySection.morning, "Morning"),
        (DaySection.midday, "Midday"),
        (DaySection.afternoon, "Afternoon"),
        (DaySection.evening, "Evening"),
        (DaySection.bedtime, "Bedtime"),
    ])
    func displayName(section: DaySection, expected: String) {
        #expect(section.displayName == expected)
    }

    @Test("Time range label matches the expected displayed range", arguments: [
        (DaySection.firstThing, "before 7:30 AM"),
        (DaySection.morning, "7:30 – 11 AM"),
        (DaySection.midday, "11 AM – 1 PM"),
        (DaySection.afternoon, "1 – 5 PM"),
        (DaySection.evening, "5 – 10 PM"),
        (DaySection.bedtime, "10 PM – midnight"),
    ])
    func timeRangeLabel(section: DaySection, expected: String) {
        #expect(section.timeRangeLabel == expected)
    }

    @Test("Start and end hour are derived correctly from the section's minute range", arguments: [
        (DaySection.firstThing, 0, 7),
        (DaySection.morning, 7, 10),
        (DaySection.midday, 11, 12),
        (DaySection.afternoon, 13, 16),
        (DaySection.evening, 17, 21),
        (DaySection.bedtime, 22, 23),
    ])
    func hourBoundaries(section: DaySection, expectedStartHour: Int, expectedEndHour: Int) {
        #expect(section.startHour == expectedStartHour)
        #expect(section.endHour == expectedEndHour)
    }

    /// Each pair marks a section's first and last minute, verifying `containing(_:)`
    /// resolves both edges (and the handoff to the next section) correctly.
    @Test("Containing(_:) resolves the correct section at each boundary minute", arguments: [
        (hour: 0, minute: 0, expected: DaySection.firstThing),
        (hour: 7, minute: 29, expected: DaySection.firstThing),
        (hour: 7, minute: 30, expected: DaySection.morning),
        (hour: 10, minute: 59, expected: DaySection.morning),
        (hour: 11, minute: 0, expected: DaySection.midday),
        (hour: 12, minute: 59, expected: DaySection.midday),
        (hour: 13, minute: 0, expected: DaySection.afternoon),
        (hour: 16, minute: 59, expected: DaySection.afternoon),
        (hour: 17, minute: 0, expected: DaySection.evening),
        (hour: 21, minute: 59, expected: DaySection.evening),
        (hour: 22, minute: 0, expected: DaySection.bedtime),
        (hour: 23, minute: 59, expected: DaySection.bedtime),
    ])
    func containingResolvesBoundaryTimes(hour: Int, minute: Int, expected: DaySection) {
        #expect(DaySection.containing(date(hour: hour, minute: minute)) == expected)
    }
}
