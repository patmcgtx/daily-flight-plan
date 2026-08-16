//
//  ModelContainers.swift
//  DailyFlightPlan
//
import SwiftData
import Foundation

extension ModelContainer {

    /// Creates a persistent container that saves to disk, synced via CloudKit.
    @MainActor
    static func persistentContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            cloudKitDatabase: .private("iCloud.com.patmcg.DailyFlightPlan")
        )
        return try ModelContainer(
            for: PlanItem.self, PlanCategory.self,
            configurations: config
        )
    }

    /// Deletes every PlanItem from the store (including routine templates).
    /// CloudKit will propagate the deletion to all devices.
    /// Two-pass: clears relationships before deleting to avoid self-referential nullify conflicts.
    @MainActor
    static func deleteAllItems(in context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<PlanItem>())
            for item in all {
                item.template = nil
                item.instances = nil
                item.categories = nil
            }
            try context.save()
            for item in all { context.delete(item) }
            try context.save()
        } catch {
            print("deleteAllItems error: \(error)")
        }
    }

    /// Deletes every PlanCategory from the store. CloudKit will propagate the deletion to all devices.
    /// Two-pass: clears relationships before deleting to avoid nullify conflicts.
    @MainActor
    static func deleteAllCategories(in context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<PlanCategory>())
            for category in all { category.items = nil }
            try context.save()
            for category in all { context.delete(category) }
            try context.save()
        } catch {
            print("deleteAllCategories error: \(error)")
        }
    }

    /// Merges duplicate PlanCategory records that share the same name.
    @MainActor
    static func deduplicateCategories(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<PlanCategory>())) ?? []
        var seen = [String: PlanCategory]()
        var toDelete = [PlanCategory]()

        for category in all {
            let key = category.name.lowercased()
            if let canonical = seen[key] {
                for item in (category.items ?? []) {
                    let current = item.categories ?? []
                    if !current.contains(canonical) {
                        item.categories = current + [canonical]
                    }
                }
                toDelete.append(category)
            } else {
                seen[key] = category
            }
        }

        guard !toDelete.isEmpty else { return }
        for category in toDelete { context.delete(category) }
        try? context.save()
    }

    /// Merges duplicate template PlanItem records.
    /// Pass 1: match by sourceID (catches seed-data duplicates from CloudKit sync races).
    /// Pass 2: match by title + daySection + weekday pattern (catches user-created duplicates).
    /// In both passes, the copy with the most instances is kept as canonical.
    @MainActor
    static func deduplicateItems(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<PlanItem>())) ?? []
        var toDelete = [PlanItem]()
        var deletedIDs = Set<ObjectIdentifier>()

        func merge(templates: [PlanItem], keyedBy key: (PlanItem) -> String) {
            // Sort so the copy with the most instances comes first — it becomes canonical.
            let sorted = templates.sorted { ($0.instances?.count ?? 0) > ($1.instances?.count ?? 0) }
            var seen = [String: PlanItem]()
            for item in sorted {
                let k = key(item)
                if let canonical = seen[k] {
                    for instance in (item.instances ?? []) { instance.template = canonical }
                    item.instances = nil
                    item.categories = nil
                    toDelete.append(item)
                    deletedIDs.insert(ObjectIdentifier(item))
                } else {
                    seen[k] = item
                }
            }
        }

        let templates = all.filter { $0.isTemplate }

        // Pass 1: sourceID match
        merge(templates: templates, keyedBy: { $0.sourceID })

        // Pass 2: content match on templates that survived pass 1
        let surviving = templates.filter { !deletedIDs.contains(ObjectIdentifier($0)) }
        merge(templates: surviving, keyedBy: { templateContentKey($0) })

        guard !toDelete.isEmpty else { return }
        for item in toDelete { context.delete(item) }
        try? context.save()
    }

    private static func templateContentKey(_ item: PlanItem) -> String {
        let order: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let days = item.recurringWeekdays
            .compactMap { order.firstIndex(of: $0) }
            .sorted()
            .map(String.init)
            .joined()
        return "\(item.title.lowercased())|\(item.daySection?.rawValue ?? "")|\(days)"
    }

    /// Computes a stable, deterministic sourceID for seeded items.
    /// The same title+section always produces the same string on every device.
    private static func sid(_ title: String, _ section: DaySection? = nil) -> String {
        let slug = title
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
            .lowercased()
            .split(separator: " ")
            .joined(separator: "-")
        return "seed.\(slug).\(section?.rawValue ?? "any")"
    }

    /// Seeds sample items into the persistent store (no-op if data already exists).
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
                title: "Talk to ppl",
                date: today,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [social, outAndAbout],
                sourceID: sid("Talk to ppl")
            ),
            PlanItem(
                title: "Things zero inbox",
                date: today,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [shallow, laptop],
                sourceID: sid("Things zero inbox")
            ),
            PlanItem(
                title: "Exercise",
                date: today,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home, health],
                sourceID: sid("Exercise")
            ),

            // First Thing habits
            PlanItem(
                title: "Slow breathing",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [relaxing],
                sourceID: sid("Slow breathing", .firstThing)
            ),
            PlanItem(
                title: "Visualize success",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [relaxing],
                sourceID: sid("Visualize success", .firstThing)
            ),
            PlanItem(
                title: "Check my weight",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home],
                sourceID: sid("Check my weight", .firstThing)
            ),
            PlanItem(
                title: "Brush my teeth 🪥",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home],
                sourceID: sid("Brush my teeth", .firstThing)
            ),
            PlanItem(
                title: "Basic stretch",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Basic stretch", .firstThing)
            ),
            PlanItem(
                title: "Jump up and down 50 times",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Jump up and down 50 times", .firstThing)
            ),
            PlanItem(
                title: "Chant or sing",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home, health],
                sourceID: sid("Chant or sing", .firstThing)
            ),
            PlanItem(
                title: "Dress like the GQ guy",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home],
                sourceID: sid("Dress like the GQ guy", .firstThing)
            ),
            PlanItem(
                title: "Take orange oil 1",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home, health],
                sourceID: sid("Take orange oil 1", .firstThing)
            ),

            // Morning habits
            PlanItem(
                title: "Use reusable cup",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [outAndAbout],
                sourceID: sid("Use reusable cup", .morning)
            ),
            PlanItem(
                title: "Have something fermented",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Have something fermented", .morning)
            ),
            PlanItem(
                title: "Update my Calendar",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [shallow, laptop],
                sourceID: sid("Update my Calendar", .morning)
            ),
            PlanItem(
                title: "Plan the day",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [shallow, laptop],
                sourceID: sid("Plan the day", .morning)
            ),
            PlanItem(
                title: "Leetcode",
                notes: " 150 challenge",
                date: today,
                daySection: .morning,
                recurringWeekdays: weekdays,
                isTemplate: true,
                categories: [deep, laptop, career],
                sourceID: sid("Leetcode", .morning)
            ),
            PlanItem(
                title: "Sing along with songs 🎤",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [fun, health, relaxing],
                sourceID: sid("Sing along with songs", .morning)
            ),
            PlanItem(
                title: "Listen to news, book, or podcast 📰",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [outAndAbout, relaxing],
                sourceID: sid("Listen to news book or podcast", .morning)
            ),
            PlanItem(
                title: "YNAB done",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [shallow, laptop],
                sourceID: sid("YNAB done", .morning)
            ),

            // Midday habits
            PlanItem(
                title: "Take my pills 💊",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Take my pills", .midday)
            ),
            PlanItem(
                title: "Eat some fruit 🍎🍊🍌",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Eat some fruit", .midday)
            ),
            PlanItem(
                title: "Eat some nuts 🥜",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Eat some nuts", .midday)
            ),
            PlanItem(
                title: "Use reusable cup",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [outAndAbout],
                sourceID: sid("Use reusable cup", .midday)
            ),

            // Afternoon habits
            PlanItem(
                title: "Macha + rooibos 🍵",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Macha rooibos", .afternoon)
            ),
            PlanItem(
                title: "Hydrate",
                notes: "Good for hypertension etc.",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Hydrate", .afternoon)
            ),
            PlanItem(
                title: "Easy calf stretches 🏃🏻‍♂️🎾",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Easy calf stretches", .afternoon)
            ),

            // Evening habits
            PlanItem(
                title: "Email zero inbox",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [laptop, shallow],
                sourceID: sid("Email zero inbox", .evening)
            ),
            PlanItem(
                title: "Snail mail done",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home, shallow],
                sourceID: sid("Snail mail done", .evening)
            ),
            PlanItem(
                title: "Take orange oil 2",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Take orange oil 2", .evening)
            ),

            // Bedtime habits
            PlanItem(
                title: "Photos cleaned up",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [laptop, shallow],
                sourceID: sid("Photos cleaned up", .bedtime)
            ),
            PlanItem(
                title: "Balance",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Balance", .bedtime)
            ),
            PlanItem(
                title: "Plan tomorrow",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [laptop, health],
                sourceID: sid("Plan tomorrow", .bedtime)
            ),
            PlanItem(
                title: "Work on my repertoire 🎶",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [relaxing, home, fun],
                sourceID: sid("Work on my repertoire", .bedtime)
            ),
            PlanItem(
                title: "Physical therapy",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health, home],
                sourceID: sid("Physical therapy", .bedtime)
            ),
            PlanItem(
                title: "Full teeth cleaning",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health, home],
                sourceID: sid("Full teeth cleaning", .bedtime)
            ),
            PlanItem(
                title: "Catch up on Wins journal",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [laptop, fun],
                sourceID: sid("Catch up on Wins journal", .bedtime)
            ),
            PlanItem(
                title: "Meditate",
                notes: "Body scan",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health, relaxing],
                sourceID: sid("Meditate", .bedtime)
            ),
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
            for: PlanItem.self, PlanCategory.self,
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
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Approach and talk with ppl")
            ),
            PlanItem(
                title: "Listen to news, book, or podcast 📰",
                date: today,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Listen to news book or podcast")
            ),

            // First Thing
            PlanItem(
                title: "Slow breathing",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Slow breathing", .firstThing)
            ),
            PlanItem(
                title: "Visualize success",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Visualize success", .firstThing)
            ),
            PlanItem(
                title: "Basic stretch",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Basic stretch", .firstThing)
            ),

            // Morning
            PlanItem(
                title: "Plan the day / prioritize Things",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Plan the day  prioritize Things", .morning)
            ),
            PlanItem(
                title: "Team standup",
                date: today,
                deadline: cal.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                recurringWeekdays: weekdays,
                isTemplate: true,
                sourceID: sid("Team standup")
            ),

            // Midday
            PlanItem(
                title: "Take my pills 💊",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Take my pills", .midday)
            ),
            PlanItem(
                title: "Eat some fruit 🍎🍊🍌",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Eat some fruit", .midday)
            ),

            // Afternoon
            PlanItem(
                title: "Hydrate (Good for hypertension etc.)",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Hydrate Good for hypertension etc", .afternoon)
            ),

            // Bedtime
            PlanItem(
                title: "Plan tomorrow",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Plan tomorrow", .bedtime)
            ),
            PlanItem(
                title: "Full teeth cleaning",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Full teeth cleaning", .bedtime)
            ),
            PlanItem(
                title: "Meditate / body scan",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                sourceID: sid("Meditate  body scan", .bedtime)
            ),
        ]

        for item in sampleItems {
            container.mainContext.insert(item)
        }
        try container.mainContext.save()

        return container
    }
}
