//
//  CategorySelectionService.swift
//  DailyFlightPlan
//
import SwiftData

/// Manages which categories are selected for filtering plan items.
/// Backed by SwiftData, so no protocol/mock needed — use an in-memory container in previews.
@Observable
class CategorySelectionService {

    private let modelContext: ModelContext
    private var _model: SelectedCategories?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var selectedCategories: [PlanCategory] {
        model?.categories ?? []
    }

    var hasSelectedCategories: Bool {
        !selectedCategories.isEmpty
    }

    func isSelected(_ category: PlanCategory) -> Bool {
        model?.contains(category) ?? false
    }

    func toggle(_ category: PlanCategory) {
        guard let m = model else { return }
        m.toggle(category)
        save()
    }

    func clearAll() {
        model?.clearAll()
        save()
    }

    /// Returns items filtered to those belonging to any selected category.
    /// If no categories are selected, all items are returned.
    func filterItems(_ items: [PlanItem]) -> [PlanItem] {
        guard hasSelectedCategories else { return items }
        let selected = selectedCategories
        return items.filter { item in
            item.categories.contains { selected.contains($0) }
        }
    }

    // MARK: Private

    private var model: SelectedCategories? {
        if let existing = _model { return existing }
        if let fetched = try? modelContext.fetch(FetchDescriptor<SelectedCategories>()).first {
            _model = fetched
            return fetched
        }
        let newModel = SelectedCategories()
        modelContext.insert(newModel)
        _model = newModel
        save()
        return newModel
    }

    private func save() {
        try? modelContext.save()
    }
}
