//
//  CategorySelectionService.swift
//  DailyFlightPlan
//
import Foundation

/// Determines how multiple selected categories are combined when filtering plan items.
enum CategoryFilterMode: String {
    /// Show items that match ANY of the selected categories (OR logic)
    case matchAny
    /// Show items that match ALL of the selected categories (AND logic)
    case matchAll
}

/// Manages which categories are currently selected for filtering plan items.
/// Selection state is device-local (UserDefaults); it is intentionally not synced to iCloud.
@Observable
class CategorySelectionService {

    private(set) var selectedNames: Set<String>

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: AppStorageKeys.selectedCategoryNames.rawValue) ?? []
        selectedNames = Set(stored)
    }

    var hasSelectedCategories: Bool { !selectedNames.isEmpty }

    /// Whether the filter mode picker should be shown (only relevant when 2+ categories selected)
    var shouldShowFilterModePicker: Bool { selectedNames.count >= 2 }

    var filterMode: CategoryFilterMode {
        get {
            let stored = UserDefaults.standard.string(forKey: AppStorageKeys.categoryFilterMode.rawValue)
            return stored.flatMap(CategoryFilterMode.init(rawValue:)) ?? .matchAny
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: AppStorageKeys.categoryFilterMode.rawValue)
        }
    }

    func setFilterMode(_ mode: CategoryFilterMode) {
        filterMode = mode
    }

    func isSelected(_ category: PlanCategory) -> Bool {
        selectedNames.contains(category.name)
    }

    func toggle(_ category: PlanCategory) {
        if selectedNames.contains(category.name) {
            selectedNames.remove(category.name)
        } else {
            selectedNames.insert(category.name)
        }
        persist()
    }

    func clearAllSelections() {
        selectedNames.removeAll()
        persist()
    }

    func filterItems(_ items: [PlanItem]) -> [PlanItem] {
        guard hasSelectedCategories else { return items }
        let names = selectedNames
        let mode = filterMode
        return items.filter { item in
            let categoryNames = Set((item.categories ?? []).map(\.name))
            switch mode {
            case .matchAny:
                return !categoryNames.isDisjoint(with: names)
            case .matchAll:
                return names.isSubset(of: categoryNames)
            }
        }
    }

    private func persist() {
        UserDefaults.standard.set(
            Array(selectedNames),
            forKey: AppStorageKeys.selectedCategoryNames.rawValue
        )
    }
}
