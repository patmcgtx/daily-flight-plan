//
//  ModelContainers.swift
//  DailyFlightPlan
//
import SwiftData
import Foundation

extension ModelContainer {

    /// Creates a persistent container that saves to disk.
    @MainActor
    static func persistentContainer() throws -> ModelContainer {
        let config = ModelConfiguration()
        return try ModelContainer(
            for: PlanItem.self, PlanCategory.self,
            configurations: config
        )
    }

    /// Creates an in-memory container seeded with sample data for previews and tests.
    @MainActor
    static func inMemorySampleContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PlanItem.self, PlanCategory.self,
            configurations: config
        )

        let today = Date.now
        let cal = Calendar.current
        let weekdays: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let everyday: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        let sampleItems: [PlanItem] = [
            PlanItem(title: "Morning run", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "Coffee", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Team standup", date: today,
                     deadline: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "Lunch with Alex", date: today, daySection: .midday),
            PlanItem(title: "Expense report", isFlagged: true, date: today, daySection: .afternoon),
            PlanItem(title: "Read", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: everyday),
        ]

        for item in sampleItems {
            container.mainContext.insert(item)
        }
        try container.mainContext.save()

        return container
    }
}
