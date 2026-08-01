//
//  SelectedCategories.swift
//  DailyFlightPlan
//
import SwiftData

/// Persists the set of plan categories currently selected for filtering items.
/// Singleton SwiftData model — only one instance should exist per container.
@Model
class SelectedCategories {

    @Relationship(deleteRule: .nullify) var categories: [PlanCategory] = []

    init() {}

    func contains(_ category: PlanCategory) -> Bool {
        categories.contains(category)
    }

    func toggle(_ category: PlanCategory) {
        if let index = categories.firstIndex(of: category) {
            categories.remove(at: index)
        } else {
            categories.append(category)
        }
    }

    func clearAll() {
        categories.removeAll()
    }
}
