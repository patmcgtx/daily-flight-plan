//
//  FlightDeckView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct FlightDeckView: View {

    var viewModel: DayViewModel
    var isDeletingData: Bool = false
    let onShowSettings: () -> Void

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue)
    private var showFlaggedOnly: Bool = false

    @AppStorage(AppStorageKeys.showCompleted.rawValue)
    private var showCompleted: Bool = false

    @AppStorage(AppStorageKeys.showRecurring.rawValue)
    private var showRecurring: Bool = true

    @AppStorage(AppStorageKeys.theme.rawValue)
    private var theme: DFPTheme = .cupertino

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlanCategory.name)
    private var allCategories: [PlanCategory]

    @State private var isAddingItem = false
    @State private var showCategorySelector = false
    @State private var isShowingCategoriesEdit = false

    // Always reset to 1 (the middle page) after a swipe commits.
    @State private var pageIndex: Int = 1

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
    }

    var body: some View {
        NavigationStack {
            swipeableContent
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .leadingBar) {
                    Button { onShowSettings() } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItemGroup(placement: .trailingBar) {
                    Menu {
                        Toggle(isOn: $showFlaggedOnly) {
                            Label("Flagged Only", systemImage: "flag.fill")
                        }
                        Toggle(isOn: $showCompleted) {
                            Label("Show Completed", systemImage: "checkmark")
                        }
                        Toggle(isOn: $showRecurring) {
                            Label("Routines", systemImage: "infinity")
                        }
                    } label: {
                        Image(systemName: isFilterActive
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(isFilterActive ? Color.accentColor : Color.primary)
                    }
                    .accessibilityLabel("Filters")

                    Button { showCategorySelector = true } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("Filter by Category")

                    Menu {
                        ForEach(DFPTheme.allCases) { option in
                            Button { theme = option } label: {
                                Label(option.localizedName, systemImage: option.menuIconName)
                            }
                        }
                    } label: {
                        Image(systemName: theme.menuIconName)
                            .foregroundStyle(theme == .cupertino ? Color.primary : Color.accentColor)
                    }
                    .accessibilityLabel("Theme")
                }

                ToolbarItem(placement: .trailingBar) {
                    Button { isAddingItem = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Item")
                }
            }
        }
        .sheet(isPresented: $isAddingItem) { ItemForm(date: viewModel.selectedDate) }
        .sheet(isPresented: $showCategorySelector) { categorySelectorSheet }
        .sheet(isPresented: $isShowingCategoriesEdit) {
            CategoriesEditView(allCategories: allCategories)
                .environment(\.modelContext, modelContext)
        }
    }

    // On iOS, a 3-page TabView gives native Photos/Calendar-style swipe animation.
    // On macOS, a simple drag gesture navigates between days.
    @ViewBuilder
    private var swipeableContent: some View {
#if os(iOS)
        TabView(selection: $pageIndex) {
            dayContent(for: date(offset: -1)).tag(0)
            dayContent(for: viewModel.selectedDate).tag(1)
            dayContent(for: date(offset: 1)).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { _, newValue in
            guard newValue != 1 else { return }
            if newValue == 0 { viewModel.goToYesterday() } else { viewModel.goToTomorrow() }
            // Snap back to the middle page without animation so fresh
            // left/right pages are ready for the next swipe.
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { pageIndex = 1 }
        }
#else
        dayContent(for: viewModel.selectedDate)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < 0 {
                            withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToTomorrow() }
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToYesterday() }
                        }
                    }
            )
#endif
    }

    @ViewBuilder
    private func dayContent(for date: Date) -> some View {
        VStack(spacing: 8) {
            Text(date, format: .dateTime.weekday(.wide))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(date, format: .dateTime.month(.abbreviated).day().year())
                .font(.largeTitle.bold())
            if Calendar.current.isDateInToday(date) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func date(offset days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: viewModel.selectedDate) ?? viewModel.selectedDate
    }

    private var categorySelectorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Category")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            if allCategories.isEmpty {
                Text("No categories yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allCategories) { category in
                            CategoryCapsule(category: category)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Button("Manage Categories") {
                showCategorySelector = false
                isShowingCategoriesEdit = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .presentationDetents([.height(160)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    FlightDeckView(viewModel: DayViewModel(), onShowSettings: {})
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
