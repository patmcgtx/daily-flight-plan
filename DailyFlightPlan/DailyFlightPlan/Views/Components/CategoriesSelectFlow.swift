//
//  CategoriesSelectFlow.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import Flow

/// Displays plan categories, allowing individual ones to be selected or unselected, with a
/// Match Any/Match All filter mode picker once 2+ categories are selected, and an entry point
/// into category management (add/rename/delete). Designed to be presented as a popover dropdown
/// anchored to a toolbar button (no internal "Done" button — dismissed by tapping outside).
struct CategoriesSelectFlow: View {

    // MARK: Environment

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

    @Environment(\.modelContext)
    private var modelContext

    // MARK: App storage

    @AppStorage(AppStorageKeys.showCategorySelectorExplanation.rawValue)
    private var showCategorySelectorExplanation: Bool = true

    // MARK: Persistence

    @Query(sort: \PlanCategory.name)
    private var allCategories: [PlanCategory]

    // MARK: View state

    @State private var isShowingEditView = false
    @State private var viewModel: CategoriesSelectFlowViewModel?

    // MARK: Views

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories")
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    Button("Clear") {
                        viewModel?.clearAllSelections()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!(viewModel?.hasSelectedCategories ?? false))

                    Divider().frame(height: 20)

                    Button("Edit") {
                        isShowingEditView = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Filter mode picker — only shown when 2+ categories are selected
            if viewModel?.shouldShowFilterModePicker == true {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Filter Mode")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Picker("Filter Mode", selection: Binding(
                            get: { viewModel?.filterMode ?? .matchAny },
                            set: { viewModel?.setFilterMode($0) }
                        )) {
                            Text("Match Any").tag(CategoryFilterMode.matchAny)
                            Text("Match All").tag(CategoryFilterMode.matchAll)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }

                    if showCategorySelectorExplanation {
                        HStack {
                            Text(viewModel?.filterModeExplanation ?? "")
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                withAnimation {
                                    showCategorySelectorExplanation = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .accessibilityLabel("Hide Explanation")
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if allCategories.isEmpty {
                Text("No categories yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    HFlow {
                        ForEach(allCategories) { category in
                            CategoryCapsule(category: category)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding()
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.default, value: viewModel?.shouldShowFilterModePicker ?? false)
        .sheet(isPresented: $isShowingEditView) {
            CategoriesEditView(allCategories: allCategories)
                .environment(\.modelContext, modelContext)
        }
        .onAppear {
            if viewModel == nil, let categorySelectionService {
                viewModel = CategoriesSelectFlowViewModel(service: categorySelectionService)
            }
        }
    }
}

#if DEBUG

#Preview {
    CategoriesSelectFlow()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
        .injectMockServices()
}

#endif
