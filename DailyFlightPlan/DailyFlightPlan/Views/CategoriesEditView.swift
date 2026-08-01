//
//  CategoriesEditView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

/// A sheet for adding, renaming, and deleting plan categories.
struct CategoriesEditView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlanCategory.name) private var allCategories: [PlanCategory]

    @State private var viewModel: CategoriesEditViewModel?
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Add Category") {
                    HStack {
                        TextField("New category name", text: Binding(
                            get: { viewModel?.newCategoryName ?? "" },
                            set: { viewModel?.newCategoryName = $0 }
                        ))
                        .focused($isAddFieldFocused)
                        .onSubmit {
                            if viewModel?.addCategory(allCategories: allCategories) == true {
                                isAddFieldFocused = true
                            }
                        }

                        Button {
                            if viewModel?.addCategory(allCategories: allCategories) == true {
                                isAddFieldFocused = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(
                            viewModel?.newCategoryName
                                .trimmingCharacters(in: .whitespaces).isEmpty ?? true
                        )
                    }
                }

                Section {
                    ForEach(allCategories) { category in
                        if viewModel?.editingCategory?.id == category.id {
                            editRow(for: category)
                        } else {
                            HStack {
                                Text(category.name)
                                Text("\(category.items.count) item\(category.items.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    withAnimation { viewModel?.startEditing(category) }
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel?.showingDeleteAlert = category
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Existing Categories")
                } footer: {
                    Text("Deleting a category removes it from all items.")
                }
            }
            .navigationTitle("Edit Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Delete Category?",
                isPresented: Binding(
                    get: { viewModel?.showingDeleteAlert != nil },
                    set: { if !$0 { viewModel?.showingDeleteAlert = nil } }
                ),
                presenting: viewModel?.showingDeleteAlert
            ) { category in
                Button("Cancel", role: .cancel) { viewModel?.showingDeleteAlert = nil }
                Button("Delete", role: .destructive) {
                    viewModel?.deleteCategory(category)
                    viewModel?.showingDeleteAlert = nil
                }
            } message: { category in
                Text("\"\(category.name)\" will be removed from all items.")
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = CategoriesEditViewModel(modelContext: modelContext)
                }
            }
        }
    }

    @ViewBuilder
    private func editRow(for category: PlanCategory) -> some View {
        let nameBinding = Binding<String>(
            get: { viewModel?.editedName ?? "" },
            set: { viewModel?.editedName = $0 }
        )
        let isEmpty = viewModel?.editedName.trimmingCharacters(in: .whitespaces).isEmpty ?? true
        HStack {
            TextField("Category name", text: nameBinding)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel?.saveEdit(for: category, allCategories: allCategories)
                }
            Button("Save") {
                viewModel?.saveEdit(for: category, allCategories: allCategories)
            }
            .buttonStyle(.bordered)
            .disabled(isEmpty)
            Button("Cancel") { viewModel?.cancelEdit() }
                .buttonStyle(.bordered)
        }
    }
}

#Preview {
    CategoriesEditView()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
