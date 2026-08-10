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

    /// Categories passed from the parent view's @Query (avoids Mac Catalyst sheet environment issues).
    var allCategories: [PlanCategory] = []

    @State private var viewModel: CategoriesEditViewModel?
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        #if os(macOS)
        macLayout
        #else
        NavigationStack {
            categoryList
                .navigationTitle("Edit Categories")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #endif
    }

    // MARK: - Mac layout

    #if os(macOS)
    private var macLayout: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Categories")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            Divider()
            categoryList
        }
        .frame(minWidth: 380, minHeight: 350)
    }
    #endif

    // MARK: - Shared list content

    private var categoryList: some View {
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
                    categoryRow(for: category)
                }
            } header: {
                Text("Existing Categories")
            } footer: {
                Text("Deleting a category removes it from all items.")
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

    @ViewBuilder
    private func categoryRow(for category: PlanCategory) -> some View {
        let editingId = viewModel?.editingCategory?.id
        if editingId == category.id {
            editRow(for: category)
        } else {
            let itemCount = category.items?.count ?? 0
            let itemLabel = "\(itemCount) item\(itemCount == 1 ? "" : "s")"
            HStack {
                Text(category.name)
                Text(itemLabel)
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
