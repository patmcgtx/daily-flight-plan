//
//  CategorySelectionServiceTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

struct CategorySelectionServiceTests {

    private let namesKey = AppStorageKeys.selectedCategoryNames.rawValue
    private let modeKey = AppStorageKeys.categoryFilterMode.rawValue

    /// Hands the test a fresh, isolated `UserDefaults` domain (seeded with `names`/`filterMode`),
    /// cleaned up afterward. Isolated per call rather than shared/restored against
    /// `UserDefaults.standard`, so this suite can't race `CategoriesSelectFlowViewModelTests` (or
    /// any other suite) over the same real keys if the test runner executes suites concurrently —
    /// `.serialized` only serializes tests *within* a suite, not across suites.
    private func withIsolatedDefaults(
        names: [String]? = nil, filterMode: CategoryFilterMode? = nil,
        perform: (UserDefaults) -> Void
    ) {
        let suiteName = "CategorySelectionServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        if let names {
            defaults.set(names, forKey: namesKey)
        }
        if let filterMode {
            defaults.set(filterMode.rawValue, forKey: modeKey)
        }
        perform(defaults)
    }

    private func item(categories: [PlanCategory]) -> PlanItem {
        PlanItem(title: "Item", date: .now, categories: categories)
    }

    // MARK: init

    @Test("init reads the previously selected category names from UserDefaults", arguments: [
        (stored: [String]?.none, expected: Set<String>()),
        (stored: [String]?.some([]), expected: Set<String>()),
        (stored: [String]?.some(["Home", "Work"]), expected: Set(["Home", "Work"])),
    ])
    func initReadsStoredSelection(stored: [String]?, expected: Set<String>) {
        withIsolatedDefaults(names: stored) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            #expect(service.selectedNames == expected)
        }
    }

    // MARK: hasSelectedCategories / isSelected

    @Test("hasSelectedCategories is true only when at least one category is selected")
    func hasSelectedCategoriesReflectsSelection() {
        withIsolatedDefaults(names: []) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            #expect(!service.hasSelectedCategories)
            service.toggle(PlanCategory(name: "Home"))
            #expect(service.hasSelectedCategories)
        }
    }

    @Test("isSelected reflects whether a category's name is in the selection")
    func isSelectedReflectsMembership() {
        withIsolatedDefaults(names: ["Home"]) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            #expect(service.isSelected(PlanCategory(name: "Home")))
            #expect(!service.isSelected(PlanCategory(name: "Work")))
        }
    }

    // MARK: toggle / clearAllSelections

    @Test("toggle adds an unselected category and removes a selected one, persisting the change")
    func toggleAddsAndRemoves() {
        withIsolatedDefaults(names: []) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            let home = PlanCategory(name: "Home")

            service.toggle(home)
            #expect(service.isSelected(home))
            #expect(defaults.stringArray(forKey: namesKey) ?? [] == ["Home"])

            service.toggle(home)
            #expect(!service.isSelected(home))
            #expect((defaults.stringArray(forKey: namesKey) ?? []).isEmpty)
        }
    }

    @Test("clearAllSelections empties the selection and persists it")
    func clearAllSelectionsEmptiesSelection() {
        withIsolatedDefaults(names: ["Home", "Work"]) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            service.clearAllSelections()
            #expect(!service.hasSelectedCategories)
            #expect((defaults.stringArray(forKey: namesKey) ?? []).isEmpty)
        }
    }

    // MARK: shouldShowFilterModePicker

    @Test("shouldShowFilterModePicker is true only once 2+ categories are selected", arguments: [
        (names: [String](), expected: false),
        (names: ["Home"], expected: false),
        (names: ["Home", "Work"], expected: true),
        (names: ["Home", "Work", "Health"], expected: true),
    ])
    func shouldShowFilterModePickerReflectsSelectionCount(names: [String], expected: Bool) {
        withIsolatedDefaults(names: names) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            #expect(service.shouldShowFilterModePicker == expected)
        }
    }

    // MARK: filterMode

    @Test("filterMode defaults to matchAny when nothing is stored")
    func filterModeDefaultsToMatchAny() {
        withIsolatedDefaults(names: []) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            #expect(service.filterMode == .matchAny)
        }
    }

    @Test("setFilterMode persists the mode so a new service instance reads it back")
    func setFilterModePersists() {
        withIsolatedDefaults(names: []) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            service.setFilterMode(.matchAll)
            #expect(service.filterMode == .matchAll)
            #expect(CategorySelectionService(defaults: defaults).filterMode == .matchAll)
        }
    }

    // MARK: filterItems

    @Test("filterItems returns every item unchanged when nothing is selected")
    func filterItemsReturnsAllWhenNoSelection() {
        withIsolatedDefaults(names: []) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            let itemWithCategory = item(categories: [PlanCategory(name: "Home")])
            let itemWithout = item(categories: [])
            let result = service.filterItems([itemWithCategory, itemWithout])
            #expect(result.map(\.uuid) == [itemWithCategory.uuid, itemWithout.uuid])
        }
    }

    @Test("filterItems with matchAny includes items with at least one selected category", arguments: [
        (categoryNames: [String](), included: false),
        (categoryNames: ["Work"], included: false),
        (categoryNames: ["Home"], included: true),
        (categoryNames: ["Home", "Work"], included: true),
    ])
    func filterItemsMatchAny(categoryNames: [String], included: Bool) {
        withIsolatedDefaults(names: ["Home"], filterMode: .matchAny) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            let subject = item(categories: categoryNames.map { PlanCategory(name: $0) })
            let result = service.filterItems([subject])
            #expect(result.map(\.uuid).contains(subject.uuid) == included)
        }
    }

    @Test("filterItems with matchAll requires every selected category to be present", arguments: [
        (categoryNames: [String](), included: false),
        (categoryNames: ["Home"], included: false),
        (categoryNames: ["Work"], included: false),
        (categoryNames: ["Home", "Work"], included: true),
        (categoryNames: ["Home", "Work", "Health"], included: true),
    ])
    func filterItemsMatchAll(categoryNames: [String], included: Bool) {
        withIsolatedDefaults(names: ["Home", "Work"], filterMode: .matchAll) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            let subject = item(categories: categoryNames.map { PlanCategory(name: $0) })
            let result = service.filterItems([subject])
            #expect(result.map(\.uuid).contains(subject.uuid) == included)
        }
    }
}
