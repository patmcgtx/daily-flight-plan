//
//  CategoriesSelectFlowViewModelTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

@MainActor
struct CategoriesSelectFlowViewModelTests {

    private let namesKey = AppStorageKeys.selectedCategoryNames.rawValue

    /// Hands the test a fresh, isolated `UserDefaults` domain (seeded with `names`), cleaned up
    /// afterward — see `CategorySelectionServiceTests.withIsolatedDefaults` for why this suite
    /// can't just share/restore `UserDefaults.standard` with that suite.
    private func withIsolatedDefaults(names: [String]?, perform: (UserDefaults) -> Void) {
        let suiteName = "CategoriesSelectFlowViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        if let names {
            defaults.set(names, forKey: namesKey)
        }
        perform(defaults)
    }

    @Test("Initially has no selected categories")
    func initiallyNoSelections() {
        withIsolatedDefaults(names: []) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            let viewModel = CategoriesSelectFlowViewModel(service: service)
            #expect(viewModel.hasSelectedCategories == false)
        }
    }

    @Test("clearAllSelections removes all categories")
    func clearAllSelections() {
        withIsolatedDefaults(names: ["Home", "Work"]) { defaults in
            let service = CategorySelectionService(defaults: defaults)
            let viewModel = CategoriesSelectFlowViewModel(service: service)

            #expect(viewModel.hasSelectedCategories == true)
            viewModel.clearAllSelections()
            #expect(viewModel.hasSelectedCategories == false)
        }
    }

    @Test("Filter mode state comes from the service")
    func filterModeState() {
        withIsolatedDefaults(names: ["Home", "Work"]) { defaults in
            let service = CategorySelectionService(defaults: defaults)
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
