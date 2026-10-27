//
//  DayTests.swift
//  DailyFlightPlanTests
//

import Testing
import SwiftData
import Foundation
@testable import DailyFlightPlan

@Suite(.serialized)
@MainActor
struct DayTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: PlanItem.self, PlanCategory.self, Day.self, configurations: config
        )
        return ModelContext(container)
    }

    @Test("A Day can be inserted, saved, and fetched back with its fields intact")
    func insertSaveFetch() throws {
        let context = try makeContext()
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 14))!
        context.insert(Day(date: date, flightName: "Deep Work", intention: "Ship the release"))
        try context.save()

        let days = try context.fetch(FetchDescriptor<Day>())
        #expect(days.count == 1)
        #expect(days.first?.flightName == "Deep Work")
        #expect(days.first?.intention == "Ship the release")
        #expect(days.first?.date == Calendar.current.startOfDay(for: date))
    }

    @Test("displayFlightNumber falls back to DFP + YYYYMMDD until a non-blank name is set",
          arguments: [("", "DFP 20260615"), ("   ", "DFP 20260615"), ("Deep Work", "Deep Work")])
    func displayFlightNumberFallsBackToDefault(entered: String, expected: String) {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9))!
        let day = Day(date: date)
        day.setFlightName(entered)

        #expect(day.displayFlightNumber == expected)
    }

    @Test("setFlightName caps the name at the maximum length")
    func flightNameIsCapped() {
        let day = Day(date: .now)
        day.setFlightName(String(repeating: "A", count: 100))

        #expect(day.flightName.count == Day.maxFlightNameLength)
    }

    @Test("Day normalizes its date to the start of the day, so any time of day maps to one row")
    func dateIsNormalized() {
        let morning = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 8))!
        let evening = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 21))!

        #expect(Day(date: morning).date == Day(date: evening).date)
    }

    @Test("Setters stamp modifiedAt, and isBlank reflects whether anything is customized",
          arguments: [("", "", true), ("  ", "\n", true), ("Deep Work", "", false), ("", "Ship it", false)])
    func settersAndIsBlank(flight: String, intention: String, expectedBlank: Bool) {
        let day = Day(date: .now)
        day.modifiedAt = Date(timeIntervalSinceReferenceDate: 0)
        day.setFlightName(flight)
        day.setIntention(intention)

        #expect(day.isBlank == expectedBlank)
        #expect(day.modifiedAt > Date(timeIntervalSinceReferenceDate: 0))
    }
}
