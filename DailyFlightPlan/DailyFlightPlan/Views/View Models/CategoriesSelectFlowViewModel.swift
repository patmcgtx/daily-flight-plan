//
//  CategoriesSelectFlowViewModel.swift
//  DailyFlightPlan
//
import Foundation

/// Manages the state and business logic for category selection.
/// A lightweight wrapper around CategorySelectionService.
@Observable @MainActor
final class CategoriesSelectFlowViewModel {

    private let service: CategorySelectionService

    /// Whether there are any selected categories
    var hasSelectedCategories: Bool { service.hasSelectedCategories }

    /// The current filter mode
    var filterMode: CategoryFilterMode { service.filterMode }

    /// Whether the filter mode picker should be shown (only relevant when 2+ categories selected)
    var shouldShowFilterModePicker: Bool { service.shouldShowFilterModePicker }

    /// Explanation text for the current filter mode
    var filterModeExplanation: String {
        filterMode == .matchAny
            ? "Shows items that have at least one selected category."
            : "Shows items that have all of the selected categories."
    }

    init(service: CategorySelectionService) {
        self.service = service
    }

    /// Clears all category selections
    func clearAllSelections() {
        service.clearAllSelections()
    }

    /// Sets the filter mode for combining multiple categories
    func setFilterMode(_ mode: CategoryFilterMode) {
        service.setFilterMode(mode)
    }
}
