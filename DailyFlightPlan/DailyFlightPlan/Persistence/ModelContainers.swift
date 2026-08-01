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
            for: PlanItem.self, PlanCategory.self, SelectedCategories.self,
            configurations: config
        )
    }

    /// Seeds sample items into the persistent store on first launch (no-op if data already exists).
    @MainActor
    static func seedSampleDataIfNeeded(in context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<PlanItem>())) == 0 else { return }

        let today = Date.now
        let cal = Calendar.current
        let weekdays: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let everyday: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        let items: [PlanItem] = [
            PlanItem(title: "Morning run", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "Coffee", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Review emails", date: today, daySection: .morning),
            PlanItem(title: "Team standup", date: today,
                     deadline: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "Lunch with Alex", date: today, daySection: .midday),
            PlanItem(title: "Expense report", notes: "Submit before end of month",
                     isFlagged: true, date: today, daySection: .afternoon),
            PlanItem(title: "1:1 with manager", date: today,
                     deadline: cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)),
            PlanItem(title: "Gym", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: [.monday, .wednesday, .friday]),
            PlanItem(title: "Read", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Buy groceries", date: today),
            PlanItem(title: "Call Mom", isFlagged: true, date: today),
        ]

        for item in items { context.insert(item) }
        do {
            try context.save()
        } catch {
            print("Failed to seed sample data: \(error)")
        }
    }

    /// Creates an in-memory container seeded with sample data for previews and tests.
    @MainActor
    static func inMemorySampleContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PlanItem.self, PlanCategory.self, SelectedCategories.self,
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
