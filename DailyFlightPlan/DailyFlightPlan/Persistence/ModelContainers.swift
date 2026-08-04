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
        let everyday: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let mwf: [Locale.Weekday] = [.monday, .wednesday, .friday]

        let items: [PlanItem] = [
            // Morning habits
            PlanItem(title: "Coffee", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Journal", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Morning run", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: mwf),
            PlanItem(title: "Review today's plan", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: weekdays),

            // Timed recurring
            PlanItem(title: "Team standup", date: today,
                     deadline: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                     isRecurring: true, recurringWeekdays: weekdays),

            // Midday
            PlanItem(title: "Lunch with Alex", date: today, daySection: .midday),

            // Afternoon
            PlanItem(title: "Clear inbox", date: today, daySection: .afternoon,
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "1:1 with manager", date: today,
                     deadline: cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)),
            PlanItem(title: "Expense report", notes: "Submit before end of month",
                     isFlagged: true, date: today, daySection: .afternoon),

            // Evening habits
            PlanItem(title: "Gym", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: mwf),
            PlanItem(title: "Walk", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: everyday),

            // Bedtime habits
            PlanItem(title: "Read", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Plan tomorrow", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: weekdays),

            // Untimed one-offs
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
        let everyday: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let mwf: [Locale.Weekday] = [.monday, .wednesday, .friday]

        let sampleItems: [PlanItem] = [
            PlanItem(title: "Coffee", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Journal", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Morning run", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: mwf),
            PlanItem(title: "Team standup", date: today,
                     deadline: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "Lunch with Alex", date: today, daySection: .midday),
            PlanItem(title: "Clear inbox", date: today, daySection: .afternoon,
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "Expense report", isFlagged: true, date: today, daySection: .afternoon),
            PlanItem(title: "Gym", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: mwf),
            PlanItem(title: "Walk", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Read", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Plan tomorrow", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: weekdays),
            PlanItem(title: "Buy groceries", date: today),
            PlanItem(title: "Call Mom", isFlagged: true, date: today),
        ]

        for item in sampleItems {
            container.mainContext.insert(item)
        }
        try container.mainContext.save()

        return container
    }
}
