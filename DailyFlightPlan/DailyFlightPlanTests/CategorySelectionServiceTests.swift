//
//  CategorySelectionServiceTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

/// Every test reads and writes the same real `UserDefaults.standard` keys, so the suite must
/// run serially — parallel tests would clobber each other's temporary stored value mid-test.
@Suite(.serialized)
struct CategorySelectionServiceTests {

    private let namesKey = AppStorageKeys.selectedCategoryNames.rawValue
    private let modeKey = AppStorageKeys.categoryFilterMode.rawValue

    /// Temporarily overrides the stored selection (and optionally filter mode) for the duration of
    /// `perform`, then restores whatever was there before, so these tests don't leak state into
    /// each other or the app.
    private func withStoredNames(
        _ names: [String]?, filterMode: CategoryFilterMode? = nil, perform: () -> Void
    ) {
        let originalNames = UserDefaults.standard.array(forKey: namesKey)
        let originalMode = UserDefaults.standard.string(forKey: modeKey)

        if let names {
            UserDefaults.standard.set(names, forKey: namesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: namesKey)
        }
        if let filterMode {
            UserDefaults.standard.set(filterMode.rawValue, forKey: modeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: modeKey)
        }

        defer {
            if let originalNames {
                UserDefaults.standard.set(originalNames, forKey: namesKey)
            } else {
                UserDefaults.standard.removeObject(forKey: namesKey)
            }
            if let originalMode {
                UserDefaults.standard.set(originalMode, forKey: modeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: modeKey)
            }
        }
        perform()
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
        withStoredNames(stored) {
            let service = CategorySelectionService()
            #expect(service.selectedNames == expected)
        }
    }

    // MARK: hasSelectedCategories / isSelected

    @Test("hasSelectedCategories is true only when at least one category is selected")
    func hasSelectedCategoriesReflectsSelection() {
        withStoredNames([]) {
            let service = CategorySelectionService()
            #expect(!service.hasSelectedCategories)
            service.toggle(PlanCategory(name: "Home"))
            #expect(service.hasSelectedCategories)
        }
    }

    @Test("isSelected reflects whether a category's name is in the selection")
    func isSelectedReflectsMembership() {
        withStoredNames(["Home"]) {
            let service = CategorySelectionService()
            #expect(service.isSelected(PlanCategory(name: "Home")))
            #expect(!service.isSelected(PlanCategory(name: "Work")))
        }
    }

    // MARK: toggle / clearAllSelections

    @Test("toggle adds an unselected category and removes a selected one, persisting the change")
    func toggleAddsAndRemoves() {
        withStoredNames([]) {
            let service = CategorySelectionService()
            let home = PlanCategory(name: "Home")

            service.toggle(home)
            #expect(service.isSelected(home))
            #expect(UserDefaults.standard.stringArray(forKey: namesKey) ?? [] == ["Home"])

            service.toggle(home)
            #expect(!service.isSelected(home))
            #expect((UserDefaults.standard.stringArray(forKey: namesKey) ?? []).isEmpty)
        }
    }

    @Test("clearAllSelections empties the selection and persists it")
    func clearAllSelectionsEmptiesSelection() {
        withStoredNames(["Home", "Work"]) {
            let service = CategorySelectionService()
            service.clearAllSelections()
            #expect(!service.hasSelectedCategories)
            #expect((UserDefaults.standard.stringArray(forKey: namesKey) ?? []).isEmpty)
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
        withStoredNames(names) {
            let service = CategorySelectionService()
            #expect(service.shouldShowFilterModePicker == expected)
        }
    }

    // MARK: filterMode

    @Test("filterMode defaults to matchAny when nothing is stored")
    func filterModeDefaultsToMatchAny() {
        withStoredNames([], filterMode: nil) {
            let service = CategorySelectionService()
            #expect(service.filterMode == .matchAny)
        }
    }

    @Test("setFilterMode persists the mode so a new service instance reads it back")
    func setFilterModePersists() {
        withStoredNames([], filterMode: nil) {
            let service = CategorySelectionService()
            service.setFilterMode(.matchAll)
            #expect(service.filterMode == .matchAll)
            #expect(CategorySelectionService().filterMode == .matchAll)
        }
    }

    // MARK: filterItems

    @Test("filterItems returns every item unchanged when nothing is selected")
    func filterItemsReturnsAllWhenNoSelection() {
        withStoredNames([]) {
            let service = CategorySelectionService()
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
        withStoredNames(["Home"], filterMode: .matchAny) {
            let service = CategorySelectionService()
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
        withStoredNames(["Home", "Work"], filterMode: .matchAll) {
            let service = CategorySelectionService()
            let subject = item(categories: categoryNames.map { PlanCategory(name: $0) })
            let result = service.filterItems([subject])
            #expect(result.map(\.uuid).contains(subject.uuid) == included)
        }
    }
}
