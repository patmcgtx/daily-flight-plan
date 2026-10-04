//
//  CategoriesSelectFlowViewModelTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

/// Shares UserDefaults keys with CategorySelectionService, so this suite must run serially too.
@MainActor
@Suite(.serialized)
struct CategoriesSelectFlowViewModelTests {

    private let namesKey = AppStorageKeys.selectedCategoryNames.rawValue
    private let modeKey = AppStorageKeys.categoryFilterMode.rawValue

    private func withStoredNames(_ names: [String]?, perform: () -> Void) {
        let originalNames = UserDefaults.standard.array(forKey: namesKey)
        let originalMode = UserDefaults.standard.string(forKey: modeKey)
        if let names {
            UserDefaults.standard.set(names, forKey: namesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: namesKey)
        }
        UserDefaults.standard.removeObject(forKey: modeKey)
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

    @Test("Initially has no selected categories")
    func initiallyNoSelections() {
        withStoredNames([]) {
            let service = CategorySelectionService()
            let viewModel = CategoriesSelectFlowViewModel(service: service)
            #expect(viewModel.hasSelectedCategories == false)
        }
    }

    @Test("clearAllSelections removes all categories")
    func clearAllSelections() {
        withStoredNames(["Home", "Work"]) {
            let service = CategorySelectionService()
            let viewModel = CategoriesSelectFlowViewModel(service: service)

            #expect(viewModel.hasSelectedCategories == true)
            viewModel.clearAllSelections()
            #expect(viewModel.hasSelectedCategories == false)
        }
    }

    @Test("Filter mode state comes from the service")
    func filterModeState() {
        withStoredNames(["Home", "Work"]) {
            let service = CategorySelectionService()
            let viewModel = CategoriesSelectFlowViewModel(service: service)

            #expect(viewModel.shouldShowFilterModePicker)
            #expect(viewModel.filterMode == .matchAny)
            #expect(viewModel.filterModeExplanation.contains("at least one"))

            viewModel.setFilterMode(.matchAll)

            #expect(viewModel.filterMode == .matchAll)
            #expect(viewModel.filterModeExplanation.contains("all of"))
        }
    }
}
