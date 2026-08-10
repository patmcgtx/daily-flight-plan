//
//  CategorySelectionService.swift
//  DailyFlightPlan
//
import Foundation
import SwiftData

/// Manages which categories are currently selected for filtering plan items.
/// Selection state is device-local (UserDefaults); it is intentionally not synced to iCloud.
@Observable
class CategorySelectionService {

    private(set) var selectedNames: Set<String>

    init() {
        let raw = UserDefaults.standard.string(forKey: AppStorageKeys.selectedCategoryNames.rawValue) ?? ""
        selectedNames = Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    var hasSelectedCategories: Bool { !selectedNames.isEmpty }

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

    func clearAll() {
        selectedNames.removeAll()
        persist()
    }

    func filterItems(_ items: [PlanItem]) -> [PlanItem] {
        guard hasSelectedCategories else { return items }
        let names = selectedNames
        return items.filter { item in
            let categories = item.categories ?? []
            return categories.contains { names.contains($0.name) }
        }
    }

    private func persist() {
        UserDefaults.standard.set(
            selectedNames.joined(separator: ","),
            forKey: AppStorageKeys.selectedCategoryNames.rawValue
        )
    }
}
