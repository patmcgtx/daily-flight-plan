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

    @Test("instanceDedupeKey differs for instances of two different templates that happen to share a title")
    func instanceDedupeKeyDiffersForDifferentTemplatesWithSameTitle() {
        let morningTemplate = PlanItem(title: "Stretch", date: day(), daySection: .morning, recurringWeekdays: [.monday], isTemplate: true, sourceID: "morning-stretch")
        let eveningTemplate = PlanItem(title: "Stretch", date: day(), daySection: .evening, recurringWeekdays: [.monday], isTemplate: true, sourceID: "evening-stretch")
        let a = item(title: "Stretch", date: day(), daySection: .morning)
        a.template = morningTemplate
        let b = item(title: "Stretch", date: day(), daySection: .evening)
        b.template = eveningTemplate
        #expect(a.instanceDedupeKey != b.instanceDedupeKey)
    }

    // MARK: coversRecurringOccurrence

    @Test("coversRecurringOccurrence is true for a drag-moved instance of the same template regardless of section")
    func coversRecurringOccurrenceMatchesMovedInstance() {
        let template = PlanItem(title: "Walk the dog", date: day(), daySection: .morning, recurringWeekdays: [.monday], isTemplate: true)
        let moved = item(title: "Walk the dog", date: day(), daySection: .evening)
        moved.template = template
        #expect(moved.coversRecurringOccurrence(ofTemplate: template, on: day()))
    }

    @Test("coversRecurringOccurrence is false for an instance of a different template that happens to share a title")
    func coversRecurringOccurrenceRejectsDifferentTemplate() {
        let templateA = PlanItem(title: "Stretch", date: day(), daySection: .morning, recurringWeekdays: [.monday], isTemplate: true, sourceID: "a")
        let templateB = PlanItem(title: "Stretch", date: day(), daySection: .evening, recurringWeekdays: [.monday], isTemplate: true, sourceID: "b")
        let instanceOfA = item(title: "Stretch", date: day(), daySection: .morning)
        instanceOfA.template = templateA
        #expect(!instanceOfA.coversRecurringOccurrence(ofTemplate: templateB, on: day()))
    }

    @Test("coversRecurringOccurrence is false for a one-off item with no template link, even when its title and day match")
    func coversRecurringOccurrenceRejectsItemWithNoTemplateLink() {
        let template = PlanItem(title: "Stretch", date: day(), daySection: .morning, recurringWeekdays: [.monday], isTemplate: true)
        let oneOff = item(title: "Stretch", date: day(), daySection: .morning)
        #expect(!oneOff.coversRecurringOccurrence(ofTemplate: template, on: day()))
    }

    @Test("coversRecurringOccurrence is false for a resolved instance of the same template on a different day")
    func coversRecurringOccurrenceRejectsDifferentDay() {
        let template = PlanItem(title: "Stretch", date: day(), daySection: .morning, recurringWeekdays: [.monday], isTemplate: true)
        let yesterdaysInstance = item(title: "Stretch", date: day(offset: -1), daySection: .morning)
        yesterdaysInstance.template = template
        #expect(!yesterdaysInstance.coversRecurringOccurrence(ofTemplate: template, on: day()))
    }
}
