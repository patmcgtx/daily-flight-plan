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

        let items: [PlanItem] = [
            // Any time habits
            PlanItem(title: "Approach and talk with ppl", date: today,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Listen to news, book, or podcast 📰", date: today,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Be singing along with songs in the car 🎤", date: today,
                     isRecurring: true, recurringWeekdays: everyday),

            // First Thing habits
            PlanItem(title: "Slow breathing", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Visualize success", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Check my weight", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Basic stretch", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Jump up and down 50 times", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Chant or sing", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Be the GQ guy", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Take orange oil", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),

            // Morning habits (Off to the races)
            PlanItem(title: "Use reusable cup", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Update my Calendar", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Plan the day / prioritize Things", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Do a Leetcode 150 challenge", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: weekdays),

            // Timed recurring (exercises deadline feature)
            PlanItem(title: "Team standup", date: today,
                     deadline: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                     isRecurring: true, recurringWeekdays: weekdays),

            // Midday habits
            PlanItem(title: "Take my pills 💊", date: today, daySection: .midday,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Eat some fruit 🍎🍊🍌", date: today, daySection: .midday,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Eat some nuts 🥜", date: today, daySection: .midday,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Use reusable cup", date: today, daySection: .midday,
                     isRecurring: true, recurringWeekdays: everyday),

            // Afternoon habits
            PlanItem(title: "Macha + rooibos 🍵", date: today, daySection: .afternoon,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Hydrate (Good for hypertension etc.)", date: today, daySection: .afternoon,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Easy calf stretches 🏃🏻‍♂️🎾", date: today, daySection: .afternoon,
                     isRecurring: true, recurringWeekdays: everyday),

            // Evening habits
            PlanItem(title: "Be teasing and challenging women", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: everyday),

            // Bedtime habits
            PlanItem(title: "Balance", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Plan tomorrow", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Play & sing music", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Full teeth cleaning", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Catch up on Wins journal", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Meditate / body scan", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
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

        let sampleItems: [PlanItem] = [
            // Any time habits
            PlanItem(title: "Approach and talk with ppl", date: today,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Listen to news, book, or podcast 📰", date: today,
                     isRecurring: true, recurringWeekdays: everyday),

            // First Thing
            PlanItem(title: "Slow breathing", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Visualize success", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Basic stretch", date: today, daySection: .firstThing,
                     isRecurring: true, recurringWeekdays: everyday),

            // Morning
            PlanItem(title: "Plan the day / prioritize Things", date: today, daySection: .morning,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Team standup", date: today,
                     deadline: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                     isRecurring: true, recurringWeekdays: weekdays),

            // Midday
            PlanItem(title: "Take my pills 💊", date: today, daySection: .midday,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Eat some fruit 🍎🍊🍌", date: today, daySection: .midday,
                     isRecurring: true, recurringWeekdays: everyday),

            // Afternoon
            PlanItem(title: "Hydrate (Good for hypertension etc.)", date: today, daySection: .afternoon,
                     isRecurring: true, recurringWeekdays: everyday),

            // Evening
            PlanItem(title: "Be teasing and challenging women", date: today, daySection: .evening,
                     isRecurring: true, recurringWeekdays: everyday),

            // Bedtime
            PlanItem(title: "Plan tomorrow", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Full teeth cleaning", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
            PlanItem(title: "Meditate / body scan", date: today, daySection: .bedtime,
                     isRecurring: true, recurringWeekdays: everyday),
        ]

        for item in sampleItems {
            container.mainContext.insert(item)
        }
        try container.mainContext.save()

        return container
    }
}
