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
        let everyday: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]

        let laptop = PlanCategory(name: "Laptop")
        let career = PlanCategory(name: "Career")
        let deep = PlanCategory(name: "Deep")
        let shallow = PlanCategory(name: "Shallow")
        let home = PlanCategory(name: "Home")
        let health = PlanCategory(name: "Health")
        let outAndAbout = PlanCategory(name: "Out and About")
        let social = PlanCategory(name: "Social")
        let relaxing = PlanCategory(name: "Relaxing")
        let fun = PlanCategory(name: "Fun")

        let items: [PlanItem] = [
            // Any time habits
            PlanItem(
                title: "Approach ppl",
                date: today,
                recurringWeekdays: everyday,
                categories: [social, outAndAbout]
            ),
            PlanItem(
                title: "Things zero inbox",
                date: today,
                recurringWeekdays: everyday,
                categories: [shallow, laptop]
            ),

            // First Thing habits
            PlanItem(
                title: "Slow breathing",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [relaxing]
            ),
            PlanItem(
                title: "Visualize success",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [relaxing]
            ),
            PlanItem(
                title: "Check my weight",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [home]
            ),
            PlanItem(
                title: "Basic stretch",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Jump up and down 50 times",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Chant or sing",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [home, health]
            ),
            PlanItem(
                title: "Dress like the GQ guy",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [home]
            ),
            PlanItem(
                title: "Take orange oil 1",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                categories: [home, health]
            ),
            
            // Morning habits (Off to the races)
            PlanItem(
                title: "Use reusable cup",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                categories: [outAndAbout]
            ),
            PlanItem(
                title: "Have something fermented",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Update my Calendar",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                categories: [shallow, laptop]
            ),
            PlanItem(
                title: "Plan the day",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                categories: [shallow, laptop]
            ),
            PlanItem(
                title: "Do a Leetcode 150 challenge",
                date: today,
                daySection: .morning,
                recurringWeekdays: weekdays,
                categories: [deep, laptop, career]
            ),
            PlanItem(
                title: "Sing along with songs 🎤",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                categories: [fun, health, relaxing]
            ),
            PlanItem(
                title: "Listen to news, book, or podcast 📰",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                categories: [outAndAbout, relaxing]
            ),
            PlanItem(
                title: "YNAB done",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                categories: [shallow, laptop]
            ),
            
            // Midday habits
            PlanItem(
                title: "Take my pills 💊",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Eat some fruit 🍎🍊🍌",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Eat some nuts 🥜",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Use reusable cup",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                categories: [outAndAbout]
            ),
            
            // Afternoon habits
            PlanItem(
                title: "Macha + rooibos 🍵",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Hydrate",
                notes: "Good for hypertension etc.",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Easy calf stretches 🏃🏻‍♂️🎾",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday,
                categories: [health]
            ),

            // Evening habits
            PlanItem(
                title: "Be teasing and challenging women",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday,
                categories: [fun, social]
            ),
            PlanItem(
                title: "Email zero inbox",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday,
                categories: [laptop, shallow]
            ),
            PlanItem(
                title: "Take orange oil 2",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday,
                categories: [health]
            ),

            // Bedtime habits
            PlanItem(
                title: "Pics cleaned up",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [laptop, shallow]
            ),
            PlanItem(
                title: "Balance",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [health]
            ),
            PlanItem(
                title: "Plan tomorrow",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [laptop, health]
            ),
            PlanItem(
                title: "Work on my repertoire 🎶",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [relaxing, home, fun]
            ),
            PlanItem(
                title: "Physical therapy",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [health, home]
            ),
            PlanItem(
                title: "Full teeth cleaning",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [health, home]
            ),
            PlanItem(
                title: "Catch up on Wins journal",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [laptop, fun]
            ),
            PlanItem(
                title: "Meditate",
                notes: "Body scan",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                categories: [health, relaxing]
            )
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
            PlanItem(
                title: "Approach and talk with ppl",
                date: today,
                recurringWeekdays: everyday
            ),
            PlanItem(
                title: "Listen to news, book, or podcast 📰",
                date: today,
                recurringWeekdays: everyday
            ),
            
            // First Thing
            PlanItem(
                title: "Slow breathing",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday
            ),
            PlanItem(
                title: "Visualize success",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday
            ),
            PlanItem(
                title: "Basic stretch",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday
            ),

            // Morning
            PlanItem(
                title: "Plan the day / prioritize Things",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday
            ),
            PlanItem(
                title: "Team standup",
                date: today,
                deadline: cal.date(
                    bySettingHour: 9,
                    minute: 30,
                    second: 0,
                    of: today
                ),
                recurringWeekdays: weekdays
            ),
            
            // Midday
            PlanItem(
                title: "Take my pills 💊",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday
            ),
            PlanItem(
                title: "Eat some fruit 🍎🍊🍌",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday
            ),
            
            // Afternoon
            PlanItem(
                title: "Hydrate (Good for hypertension etc.)",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday
            ),
            
            // Evening
            PlanItem(
                title: "Be teasing and challenging women",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday
            ),
            
            // Bedtime
            PlanItem(
                title: "Plan tomorrow",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday
            ),
            PlanItem(
                title: "Full teeth cleaning",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday
            ),
            PlanItem(
                title: "Meditate / body scan",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday
            ),
        ]

        for item in sampleItems {
            container.mainContext.insert(item)
        }
        try container.mainContext.save()

        return container
    }
}
