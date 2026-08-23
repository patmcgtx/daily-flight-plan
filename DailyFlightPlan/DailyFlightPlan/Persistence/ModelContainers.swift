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
    /// Uses the same two-phase save pattern as deleteAllItems to satisfy SwiftData's
    /// self-referential nullify rules before deletion.
    @MainActor
    static func deduplicateItems(in context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<PlanItem>())
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
                        item.template = nil
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
            // Phase 1: commit relationship changes before deletion (required for self-referential nullify)
            try context.save()
            // Phase 2: delete and commit
            for item in toDelete { context.delete(item) }
            try context.save()
            print("deduplicateItems: removed \(toDelete.count) duplicate template(s)")
        } catch {
            print("deduplicateItems error: \(error)")
        }
    }

    /// Removes duplicate per-day instances (isTemplate == false) that share the same
    /// title, daySection, and calendar date. Does not rely on the template relationship,
    /// which may be nil while CloudKit is still delivering records.
    /// Prefers completed/skipped instances over pending ones when choosing which to keep.
    @MainActor
    static func deduplicateInstances(in context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<PlanItem>())
            let cal = Calendar.current
            var seen = [String: PlanItem]()
            var toDelete = [PlanItem]()

            for instance in all where !instance.isTemplate {
                let dayKey = cal.startOfDay(for: instance.date).timeIntervalSinceReferenceDate
                let key = "\(instance.title.lowercased())|\(instance.daySection?.rawValue ?? "")|\(dayKey)"
                if let existing = seen[key] {
                    if existing.status == .pending && instance.status != .pending {
                        toDelete.append(existing)
                        seen[key] = instance
                    } else {
                        toDelete.append(instance)
                    }
                } else {
                    seen[key] = instance
                }
            }

            guard !toDelete.isEmpty else { return }
            for instance in toDelete { instance.template = nil }
            try context.save()
            for instance in toDelete { context.delete(instance) }
            try context.save()
            print("deduplicateInstances: removed \(toDelete.count) duplicate instance(s)")
        } catch {
            print("deduplicateInstances error: \(error)")
        }
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

        let health = PlanCategory(name: "Health")
        let work = PlanCategory(name: "Work")
        let home = PlanCategory(name: "Home")
        let personal = PlanCategory(name: "Personal")

        let weekends: [Locale.Weekday] = [.saturday, .sunday]

        let items: [PlanItem] = [
            // Open — any time
            PlanItem(
                title: "Exercise",
                date: today,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Exercise")
            ),

            // First Thing — everyday
            PlanItem(
                title: "Morning stretch",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Morning stretch", .firstThing)
            ),
            PlanItem(
                title: "Brush teeth",
                date: today,
                daySection: .firstThing,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home],
                sourceID: sid("Brush teeth", .firstThing)
            ),

            // Morning
            PlanItem(
                title: "Plan the day",
                date: today,
                daySection: .morning,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [personal],
                sourceID: sid("Plan the day", .morning)
            ),
            PlanItem(
                title: "Check email",
                date: today,
                daySection: .morning,
                recurringWeekdays: weekdays,
                isTemplate: true,
                categories: [work],
                sourceID: sid("Check email", .morning)
            ),

            // Midday — everyday
            PlanItem(
                title: "Take vitamins",
                date: today,
                daySection: .midday,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [health],
                sourceID: sid("Take vitamins", .midday)
            ),

            // Afternoon
            PlanItem(
                title: "Wrap up work",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: weekdays,
                isTemplate: true,
                categories: [work],
                sourceID: sid("Wrap up work", .afternoon)
            ),
            PlanItem(
                title: "Catch up on chores",
                date: today,
                daySection: .afternoon,
                recurringWeekdays: weekends,
                isTemplate: true,
                categories: [home],
                sourceID: sid("Catch up on chores", .afternoon)
            ),

            // Evening — everyday
            PlanItem(
                title: "Tidy up",
                date: today,
                daySection: .evening,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [home],
                sourceID: sid("Tidy up", .evening)
            ),

            // Bedtime — everyday
            PlanItem(
                title: "Plan tomorrow",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [personal],
                sourceID: sid("Plan tomorrow", .bedtime)
            ),
            PlanItem(
                title: "Read",
                date: today,
                daySection: .bedtime,
                recurringWeekdays: everyday,
                isTemplate: true,
                categories: [personal],
                sourceID: sid("Read", .bedtime)
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
