//
//  ModelContainersTests.swift
//  DailyFlightPlanTests
//

import Testing
import SwiftData
import Foundation
@testable import DailyFlightPlan

@Suite(.serialized)
@MainActor
struct ModelContainersTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PlanItem.self, PlanCategory.self, configurations: config)
        return ModelContext(container)
    }

    private func fetchItems(_ context: ModelContext) throws -> [PlanItem] {
        try context.fetch(FetchDescriptor<PlanItem>())
    }

    // MARK: deleteAllItems

    @Test("deleteAllItems removes every PlanItem, including template/instance pairs, from the store")
    func deleteAllItemsRemovesEverything() throws {
        let context = try makeContext()
        let template = PlanItem(title: "Habit", date: .now, recurringWeekdays: [.monday], isTemplate: true)
        context.insert(template)
        let instance = PlanItem(title: "Habit", date: .now)
        instance.template = template
        context.insert(instance)
        try context.save()

        ModelContainer.deleteAllItems(in: context)

        let remaining = try fetchItems(context)
        #expect(remaining.isEmpty)
    }

    // MARK: deleteAllCategories

    @Test("deleteAllCategories removes every PlanCategory from the store")
    func deleteAllCategoriesRemovesEverything() throws {
        let context = try makeContext()
        let category = PlanCategory(name: "Home")
        context.insert(category)
        context.insert(PlanItem(title: "Item", date: .now, categories: [category]))
        try context.save()

        ModelContainer.deleteAllCategories(in: context)

        let remaining = try context.fetch(FetchDescriptor<PlanCategory>())
        #expect(remaining.isEmpty)
    }

    // MARK: deduplicateCategories

    @Test("deduplicateCategories merges categories sharing the same name, case-insensitively, and re-points affected items to the survivor")
    func deduplicateCategoriesMergesCaseInsensitiveDuplicates() throws {
        let context = try makeContext()
        let first = PlanCategory(name: "Home")
        let second = PlanCategory(name: "home")
        context.insert(first)
        context.insert(second)
        let item = PlanItem(title: "Item", date: .now, categories: [second])
        context.insert(item)
        try context.save()

        ModelContainer.deduplicateCategories(in: context)

        let remaining = try context.fetch(FetchDescriptor<PlanCategory>())
        #expect(remaining.count == 1)
        let survivor = remaining[0]
        #expect(survivor.name.lowercased() == "home")
        #expect((item.categories ?? []).contains(survivor))
    }

    @Test("deduplicateCategories leaves distinct category names untouched")
    func deduplicateCategoriesLeavesDistinctNamesAlone() throws {
        let context = try makeContext()
        context.insert(PlanCategory(name: "Home"))
        context.insert(PlanCategory(name: "Work"))
        try context.save()

        ModelContainer.deduplicateCategories(in: context)

        let remaining = try context.fetch(FetchDescriptor<PlanCategory>())
        #expect(Set(remaining.map(\.name)) == ["Home", "Work"])
    }

    // MARK: deduplicateItems

    @Test("deduplicateItems merges templates sharing the same sourceID, keeping the copy with more instances as canonical and redirecting the other's instances to it")
    func deduplicateItemsMergesBySourceID() throws {
        let context = try makeContext()
        let sourceID = "seed.habit.any"
        let richer = PlanItem(title: "Habit", date: .now, recurringWeekdays: [.monday], isTemplate: true, sourceID: sourceID)
        let sparser = PlanItem(title: "Habit", date: .now, recurringWeekdays: [.monday], isTemplate: true, sourceID: sourceID)
        context.insert(richer)
        context.insert(sparser)

        let richerInstanceA = PlanItem(title: "Habit", date: .now)
        richerInstanceA.template = richer
        context.insert(richerInstanceA)
        let richerInstanceB = PlanItem(title: "Habit", date: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        richerInstanceB.template = richer
        context.insert(richerInstanceB)

        let sparserInstance = PlanItem(title: "Habit", date: .now)
        sparserInstance.template = sparser
        context.insert(sparserInstance)

        try context.save()

        ModelContainer.deduplicateItems(in: context)

        let templates = try fetchItems(context).filter(\.isTemplate)
        #expect(templates.count == 1)
        #expect((templates[0].instances ?? []).count == 3)
    }

    @Test("deduplicateItems merges templates that share the same title, day section, and weekday pattern, even with different sourceIDs")
    func deduplicateItemsMergesByContentWhenSourceIDsDiffer() throws {
        let context = try makeContext()
        let a = PlanItem(title: "Stretch", date: .now, daySection: .morning, recurringWeekdays: [.monday, .wednesday], isTemplate: true, sourceID: "a")
        let b = PlanItem(title: "Stretch", date: .now, daySection: .morning, recurringWeekdays: [.monday, .wednesday], isTemplate: true, sourceID: "b")
        context.insert(a)
        context.insert(b)
        try context.save()

        ModelContainer.deduplicateItems(in: context)

        let templates = try fetchItems(context).filter(\.isTemplate)
        #expect(templates.count == 1)
    }

    @Test("deduplicateItems leaves distinct templates untouched")
    func deduplicateItemsLeavesDistinctTemplatesAlone() throws {
        let context = try makeContext()
        let a = PlanItem(title: "Stretch", date: .now, daySection: .morning, recurringWeekdays: [.monday], isTemplate: true, sourceID: "a")
        let b = PlanItem(title: "Read", date: .now, daySection: .bedtime, recurringWeekdays: [.tuesday], isTemplate: true, sourceID: "b")
        context.insert(a)
        context.insert(b)
        try context.save()

        ModelContainer.deduplicateItems(in: context)

        let templates = try fetchItems(context).filter(\.isTemplate)
        #expect(templates.count == 2)
    }

    // MARK: deduplicateInstances

    @Test("deduplicateInstances keeps the non-pending copy over a pending duplicate", arguments: [ItemStatus.completed, ItemStatus.canceled])
    func deduplicateInstancesPrefersNonPendingStatus(nonPendingStatus: ItemStatus) throws {
        let context = try makeContext()
        let day = Calendar.current.startOfDay(for: .now)
        context.insert(PlanItem(title: "Habit", date: day, daySection: .morning, status: .pending))
        context.insert(PlanItem(title: "Habit", date: day, daySection: .morning, status: nonPendingStatus))
        try context.save()

        ModelContainer.deduplicateInstances(in: context)

        let remaining = try fetchItems(context).filter { !$0.isTemplate }
        #expect(remaining.count == 1)
        #expect(remaining[0].status == nonPendingStatus)
    }

    @Test("deduplicateInstances removes duplicate instances sharing the same title, day section, and day, keeping exactly one")
    func deduplicateInstancesRemovesDuplicatesKeepingOne() throws {
        let context = try makeContext()
        let day = Calendar.current.startOfDay(for: .now)
        context.insert(PlanItem(title: "Habit", date: day, daySection: .morning, status: .pending))
        context.insert(PlanItem(title: "Habit", date: day, daySection: .morning, status: .pending))
        try context.save()

        ModelContainer.deduplicateInstances(in: context)

        let remaining = try fetchItems(context).filter { !$0.isTemplate }
        #expect(remaining.count == 1)
    }

    @Test("deduplicateInstances leaves instances with different titles, sections, or days untouched")
    func deduplicateInstancesLeavesDistinctInstancesAlone() throws {
        let context = try makeContext()
        let day = Calendar.current.startOfDay(for: .now)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        context.insert(PlanItem(title: "Habit", date: day, daySection: .morning))
        context.insert(PlanItem(title: "Habit", date: nextDay, daySection: .morning))
        try context.save()

        ModelContainer.deduplicateInstances(in: context)

        let remaining = try fetchItems(context).filter { !$0.isTemplate }
        #expect(remaining.count == 2)
    }

    // MARK: seedSampleDataIfNeeded

    @Test("seedSampleDataIfNeeded inserts sample template items into an empty store")
    func seedSampleDataInsertsWhenEmpty() throws {
        let context = try makeContext()
        ModelContainer.seedSampleDataIfNeeded(in: context)
        let items = try fetchItems(context)
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.isTemplate })
    }

    @Test("seedSampleDataIfNeeded does nothing when the store already has items")
    func seedSampleDataNoOpWhenNotEmpty() throws {
        let context = try makeContext()
        context.insert(PlanItem(title: "Existing", date: .now))
        try context.save()

        ModelContainer.seedSampleDataIfNeeded(in: context)

        let items = try fetchItems(context)
        #expect(items.map(\.title) == ["Existing"])
    }

    // MARK: inMemorySampleContainer

    @Test("inMemorySampleContainer returns a fresh container pre-populated with recurring template items")
    func inMemorySampleContainerIsPrePopulated() throws {
        let container = try ModelContainer.inMemorySampleContainer()
        let items = try container.mainContext.fetch(FetchDescriptor<PlanItem>())
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.isTemplate })
    }
}
