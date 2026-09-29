//
//  PlanItemTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

struct PlanItemTests {

    private func day(offset: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1 + offset
        return Calendar.current.date(from: components)!
    }

    private func item(title: String, date: Date, daySection: DaySection? = nil) -> PlanItem {
        PlanItem(title: title, date: date, daySection: daySection)
    }

    // MARK: dailyOccurrenceKey

    @Test("dailyOccurrenceKey is identical for the same title and day regardless of day section", arguments: [
        (DaySection?.none, DaySection?.some(.morning)),
        (DaySection?.some(.morning), DaySection?.some(.evening)),
        (DaySection?.some(.firstThing), DaySection?.none),
    ])
    func sameDayDifferentSectionMatches(sectionA: DaySection?, sectionB: DaySection?) {
        let a = item(title: "Walk the dog", date: day(), daySection: sectionA)
        let b = item(title: "Walk the dog", date: day(), daySection: sectionB)
        #expect(a.dailyOccurrenceKey == b.dailyOccurrenceKey)
    }

    @Test("dailyOccurrenceKey matches titles case-insensitively")
    func matchesTitleCaseInsensitively() {
        let a = item(title: "Walk the Dog", date: day())
        let b = item(title: "walk the dog", date: day())
        #expect(a.dailyOccurrenceKey == b.dailyOccurrenceKey)
    }

    @Test("dailyOccurrenceKey differs for the same title on different days")
    func differsAcrossDays() {
        let today = item(title: "Walk the dog", date: day())
        let tomorrow = item(title: "Walk the dog", date: day(offset: 1))
        #expect(today.dailyOccurrenceKey != tomorrow.dailyOccurrenceKey)
    }

    @Test("dailyOccurrenceKey differs for different titles on the same day")
    func differsAcrossTitles() {
        let a = item(title: "Walk the dog", date: day())
        let b = item(title: "Feed the cat", date: day())
        #expect(a.dailyOccurrenceKey != b.dailyOccurrenceKey)
    }

    @Test("The static and instance forms of dailyOccurrenceKey agree")
    func staticAndInstanceFormsAgree() {
        let subject = item(title: "Walk the dog", date: day(), daySection: .morning)
        #expect(subject.dailyOccurrenceKey == PlanItem.dailyOccurrenceKey(title: "Walk the dog", date: day()))
    }

    // MARK: instanceDedupeKey

    @Test("instanceDedupeKey matches across day sections for a recurring instance with a resolved template link")
    func instanceDedupeKeyIgnoresSectionForRecurringInstance() {
        let template = PlanItem(title: "Walk the dog", date: day(), daySection: .morning, recurringWeekdays: [.monday], isTemplate: true)
        let a = item(title: "Walk the dog", date: day(), daySection: .morning)
        a.template = template
        let b = item(title: "Walk the dog", date: day(), daySection: .evening)
        b.template = template
        #expect(a.instanceDedupeKey == b.instanceDedupeKey)
    }

    @Test("instanceDedupeKey differs across day sections for a one-off item with no template")
    func instanceDedupeKeyIncludesSectionForOneOffItem() {
        let a = item(title: "Call mom", date: day(), daySection: .morning)
        let b = item(title: "Call mom", date: day(), daySection: .evening)
        #expect(a.instanceDedupeKey != b.instanceDedupeKey)
    }

    @Test("instanceDedupeKey matches across day sections for a one-off item only when the section is the same")
    func instanceDedupeKeyMatchesSameSectionOneOffItem() {
        let a = item(title: "Call mom", date: day(), daySection: .morning)
        let b = item(title: "Call mom", date: day(), daySection: .morning)
        #expect(a.instanceDedupeKey == b.instanceDedupeKey)
    }
}
