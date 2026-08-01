//
//  CategoriesEditViewModel.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

@Observable @MainActor
final class CategoriesEditViewModel {

    var newCategoryName: String = ""
    var editingCategory: PlanCategory?
    var editedName: String = ""
    var showingDeleteAlert: PlanCategory?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func addCategory(allCategories: [PlanCategory]) -> Bool {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard !allCategories.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return false }
        modelContext.insert(PlanCategory(name: trimmed))
        do {
            try modelContext.save()
            newCategoryName = ""
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    func startEditing(_ category: PlanCategory) {
        editingCategory = category
        editedName = category.name
    }

    @discardableResult
    func saveEdit(for category: PlanCategory, allCategories: [PlanCategory]) -> Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard !allCategories.contains(where: {
            $0.id != category.id && $0.name.lowercased() == trimmed.lowercased()
        }) else { return false }
        category.name = trimmed
        do {
            try modelContext.save()
            cancelEdit()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    func cancelEdit() {
        editingCategory = nil
        editedName = ""
    }

    @discardableResult
    func deleteCategory(_ category: PlanCategory) -> Bool {
        modelContext.delete(category)
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }
}
