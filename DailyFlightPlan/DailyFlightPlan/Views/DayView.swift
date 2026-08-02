//
//  DayView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import Flow

struct DayView: View {

    @State private var viewModel = DayViewModel()

    @Query private var allItems: [PlanItem]

    @AppStorage(AppStorageKeys.theme.rawValue)
    private var theme: DFPTheme = .cupertino

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue)
    private var showFlaggedOnly: Bool = false

    @AppStorage(AppStorageKeys.showCompleted.rawValue)
    private var showCompleted: Bool = false

    @AppStorage(AppStorageKeys.showRecurring.rawValue)
    private var showRecurring: Bool = true

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

    @Query(sort: \PlanCategory.name)
    private var allCategories: [PlanCategory]

    @State private var isShowingCategoriesEdit = false
    @State private var isAddingItem = false
    @State private var itemToEdit: PlanItem? = nil

    private var selectedDateNonCanceledItems: [PlanItem] {
        allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate)
            && $0.status != .canceled
        }
    }

    private var itemsForSelectedDate: [PlanItem] {
        let filtered = allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate)
            && (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
            && (showRecurring || !$0.isRecurring)
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            dayScrollView
                .id(viewModel.selectedDate)
                .transition(dayTransition)
        }
        .clipped()
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(isPresented: $isShowingCategoriesEdit) {
            CategoriesEditView()
        }
        .sheet(isPresented: $isAddingItem) {
            ItemForm(date: viewModel.selectedDate)
        }
        .sheet(item: $itemToEdit) { item in
            ItemForm(item: item)
        }
    }

    private var dayTransition: AnyTransition {
        viewModel.forwardNavigation
            ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading),  removal: .move(edge: .trailing))
    }

    // MARK: Sticky header

    private var headerView: some View {
        VStack(spacing: 8) {
            dateNavRow
            filterRow
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var dateNavRow: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToYesterday() }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 20)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Previous Day")

            Spacer()

            VStack(spacing: 1) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(viewModel.selectedDate, format: .dateTime.month(.abbreviated).day())
                        .font(.title2.bold())
                    if !viewModel.isToday {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToToday() }
                        } label: {
                            Image(systemName: "scope")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Go to Today")
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                progressRing
                Button { } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Settings")
                Menu {
                    ForEach(DFPTheme.allCases) { option in
                        Button { theme = option } label: {
                            Label(option.localizedName, systemImage: option.menuIconName)
                        }
                    }
                } label: {
                    Image(systemName: theme.menuIconName)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Theme")
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToTomorrow() }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 20)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Next Day")
            }
        }
        .padding(.horizontal)
    }

    private var progressRing: some View {
        let items = selectedDateNonCanceledItems
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0
        return ProgressRingView(progress: progress, completed: completed, total: total)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterToggle("Flagged", icon: "flag.fill", isActive: showFlaggedOnly) {
                    showFlaggedOnly.toggle()
                }
                filterToggle("Done", icon: "checkmark", isActive: showCompleted) {
                    showCompleted.toggle()
                }
                filterToggle("Recurring", icon: "infinity", isActive: showRecurring) {
                    showRecurring.toggle()
                }
                if !allCategories.isEmpty {
                    Divider().frame(height: 20)
                    ForEach(allCategories) { category in
                        CategoryCapsule(category: category)
                    }
                }
                Button {
                    isShowingCategoriesEdit = true
                } label: {
                    Image(systemName: "tag")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Manage Categories")
            }
            .padding(.horizontal)
        }
    }

    private func filterToggle(
        _ title: String, icon: String, isActive: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .background {
            if isActive {
                Capsule().fill(Color.accentColor)
            } else {
                Capsule().fill(.regularMaterial)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Scrollable day content

    private var dayScrollView: some View {
        let selectedDateItems = itemsForSelectedDate
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(DaySection.allCases) { section in
                        DaySectionView(
                            section: section,
                            sectionPills: viewModel.sectionPills(section, from: selectedDateItems),
                            deadlineRows: viewModel.deadlineRows(section, from: selectedDateItems),
                            showNowBar: viewModel.currentSection == section,
                            isCollapsed: viewModel.isCollapsed(section),
                            onToggle: {
                                withAnimation(.spring(duration: 0.25)) {
                                    viewModel.toggleCollapsed(section)
                                }
                            }
                        )
                        .id(section)
                    }

                    anyTimeSection(items: selectedDateItems)
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .safeAreaInset(edge: .bottom) {
                addButton
            }
            .onAppear {
                if let current = viewModel.currentSection {
                    proxy.scrollTo(current, anchor: .top)
                }
            }
        }
    }

    // MARK: Any time section

    private func anyTimeSection(items: [PlanItem]) -> some View {
        let anyTimeItems = viewModel.anyTimeItems(from: items)
        return Group {
            if !anyTimeItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Any Time")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    HFlow(itemSpacing: 8, rowSpacing: 8) {
                        ForEach(anyTimeItems) { item in
                            ItemPillView(item: item, isMissed: viewModel.isMissed(item))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: Add button

    private var addButton: some View {
        Button { isAddingItem = true } label: {
            Label("Add Item", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
        }
        .buttonStyle(.glass)
        .padding(.bottom, 12)
    }
}

#Preview {
    DayView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
