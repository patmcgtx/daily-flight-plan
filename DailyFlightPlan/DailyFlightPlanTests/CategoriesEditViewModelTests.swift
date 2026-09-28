//
//  CategoriesEditViewModelTests.swift
//  DailyFlightPlanTests
//

import Testing
import SwiftData
import Foundation
@testable import DailyFlightPlan

@Suite(.serialized)
@MainActor
struct CategoriesEditViewModelTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PlanItem.self, PlanCategory.self, configurations: config)
        return ModelContext(container)
    }

    private func fetchCategories(_ context: ModelContext) throws -> [PlanCategory] {
        try context.fetch(FetchDescriptor<PlanCategory>())
    }

    // MARK: addCategory

    @Test("addCategory does nothing when the name is empty or whitespace-only", arguments: ["", "   "])
    func addCategoryRejectsBlankName(name: String) throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        viewModel.newCategoryName = name
        let result = viewModel.addCategory(allCategories: [])
        #expect(!result)
        #expect(try fetchCategories(context).isEmpty)
    }

    @Test("addCategory rejects a name that duplicates an existing category, case-insensitively")
    func addCategoryRejectsDuplicateName() throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        let existing = PlanCategory(name: "Home")
        viewModel.newCategoryName = "home"
        let result = viewModel.addCategory(allCategories: [existing])
        #expect(!result)
        #expect(try fetchCategories(context).isEmpty)
    }

    @Test("addCategory trims whitespace, inserts the new category, and clears the input")
    func addCategoryInsertsTrimmedName() throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        viewModel.newCategoryName = "  Home  "
        let result = viewModel.addCategory(allCategories: [])
        #expect(result)
        #expect(viewModel.newCategoryName.isEmpty)
        let saved = try fetchCategories(context)
        #expect(saved.map(\.name) == ["Home"])
    }

    // MARK: startEditing / cancelEdit

    @Test("startEditing populates editingCategory and editedName; cancelEdit clears them")
    func startEditingAndCancelEdit() throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        let category = PlanCategory(name: "Home")

        viewModel.startEditing(category)
        #expect(viewModel.editingCategory === category)
        #expect(viewModel.editedName == "Home")

        viewModel.cancelEdit()
        #expect(viewModel.editingCategory == nil)
        #expect(viewModel.editedName.isEmpty)
    }

    // MARK: saveEdit

    @Test("saveEdit does nothing when the edited name is empty or whitespace-only", arguments: ["", "   "])
    func saveEditRejectsBlankName(name: String) throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        let category = PlanCategory(name: "Home")
        context.insert(category)
        try context.save()

        viewModel.startEditing(category)
        viewModel.editedName = name
        let result = viewModel.saveEdit(for: category, allCategories: [category])
        #expect(!result)
        #expect(category.name == "Home")
        #expect(viewModel.editingCategory === category)
    }

    @Test("saveEdit rejects a name that duplicates a different category, case-insensitively")
    func saveEditRejectsDuplicateOfAnotherCategory() throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        let home = PlanCategory(name: "Home")
        let work = PlanCategory(name: "Work")
        context.insert(home)
        context.insert(work)
        try context.save()

        viewModel.startEditing(home)
        viewModel.editedName = "work"
        let result = viewModel.saveEdit(for: home, allCategories: [home, work])
        #expect(!result)
        #expect(home.name == "Home")
    }

    @Test("saveEdit allows re-saving a category's own name, including a case-only change")
    func saveEditAllowsRenamingToOwnNameCaseChange() throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        let home = PlanCategory(name: "Home")
        context.insert(home)
        try context.save()

        viewModel.startEditing(home)
        viewModel.editedName = "home"
        let result = viewModel.saveEdit(for: home, allCategories: [home])
        #expect(result)
        #expect(home.name == "home")
    }

    @Test("saveEdit trims whitespace, updates the category, saves, and cancels editing")
    func saveEditUpdatesNameAndCancelsEditing() throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        let home = PlanCategory(name: "Home")
        context.insert(home)
        try context.save()

        viewModel.startEditing(home)
        viewModel.editedName = "  Household  "
        let result = viewModel.saveEdit(for: home, allCategories: [home])
        #expect(result)
        #expect(home.name == "Household")
        #expect(viewModel.editingCategory == nil)
        #expect(viewModel.editedName.isEmpty)
    }

    // MARK: deleteCategory

    @Test("deleteCategory removes the category from the store")
    func deleteCategoryRemovesFromStore() throws {
        let context = try makeContext()
        let viewModel = CategoriesEditViewModel(modelContext: context)
        let home = PlanCategory(name: "Home")
        context.insert(home)
        try context.save()

        let result = viewModel.deleteCategory(home)
        #expect(result)
        #expect(try fetchCategories(context).isEmpty)
    }
}
