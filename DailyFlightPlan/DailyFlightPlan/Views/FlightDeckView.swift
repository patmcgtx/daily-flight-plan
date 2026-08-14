//
//  FlightDeckView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import Flow

// NOTE: struct is named FlightPlanView; file kept as FlightDeckView.swift to avoid
// Xcode project file churn until a clean rename can be done via Xcode.
struct FlightPlanView: View {

    var viewModel: DayViewModel
    var isDeletingData: Bool = false
    let onShowSettings: () -> Void

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @Query(sort: \PlanCategory.name)
    private var allCategories: [PlanCategory]

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

    @State private var pageIndex: Int = 1
    @State private var itemToEdit: PlanItem?
    @State private var addingToSection: DaySection? = nil
    @State private var addingItemForDate: Date? = nil
    @State private var isAddingItem = false
    @State private var showCategorySelector = false
    @State private var isShowingCategoriesEdit = false
    @State private var expandedSections: Set<DaySection> = []

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
            || !(categorySelectionService?.selectedNames.isEmpty ?? true)
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
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(isPresented: $isAddingItem) {
            ItemForm(date: viewModel.selectedDate)
        }
        .sheet(isPresented: Binding(
            get: { addingToSection != nil },
            set: { if !$0 { addingToSection = nil; addingItemForDate = nil } }
        )) {
            if let section = addingToSection, let date = addingItemForDate {
                ItemForm(date: date, section: section)
            }
        }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
        .sheet(isPresented: $showCategorySelector) { categorySelectorSheet }
        .sheet(isPresented: $isShowingCategoriesEdit) {
            CategoriesEditView(allCategories: allCategories)
                .environment(\.modelContext, modelContext)
        }
        .onAppear { initializeExpandedSections() }
        .onChange(of: viewModel.selectedDate) { initializeExpandedSections() }
        .onChange(of: filterKey) { applyFilterToExpandedSections() }
    }

    // MARK: - Swipe navigation

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

    private func date(offset days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: viewModel.selectedDate) ?? viewModel.selectedDate
    }

    // MARK: - Day content

    @ViewBuilder
    private func dayContent(for date: Date) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                dayLabel(for: date)

                ForEach(DaySection.allCases) { section in
                    sectionCard(section, date: date)
                }

                let openItems = viewModel.anyTimeItems(from: activeItems(for: date))
                if !openItems.isEmpty {
                    openCard(openItems, date: date)
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
    }

    private func dayLabel(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        return ZStack {
            VStack(spacing: 2) {
                Text(isToday ? "Today" : date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.title2.bold())
                    .monospacedDigit()
            }

            if !isToday {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToToday() }
                    } label: {
                        Image(systemName: "scope")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to Today")
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func activeItems(for date: Date) -> [PlanItem] {
        guard !isDeletingData else { return [] }
        let filtered = allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
            && (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
            && (showRecurring || !$0.isRecurring)
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    // Unfiltered items for a date — used for raw section counts in the ring.
    private func rawItems(for date: Date) -> [PlanItem] {
        guard !isDeletingData else { return [] }
        return allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
            && $0.status != .canceled
        }
    }

    // Combines all filter states into a single comparable string so a single
    // onChange can react to any filter change (including category toggles).
    private var filterKey: String {
        let cats = categorySelectionService?.selectedNames.sorted().joined() ?? ""
        return "\(showFlaggedOnly)-\(showCompleted)-\(showRecurring)-\(cats)"
    }

    private func initializeExpandedSections() {
        expandedSections = []
        if let current = viewModel.currentSection, viewModel.isToday {
            expandedSections = [current]
        }
    }

    private func applyFilterToExpandedSections() {
        if isFilterActive {
            expandedSections = Set(DaySection.allCases.filter { section in
                let items = viewModel.sectionPills(section, from: activeItems(for: viewModel.selectedDate))
                           + viewModel.deadlineRows(section, from: activeItems(for: viewModel.selectedDate))
                return !items.isEmpty
            })
        } else {
            initializeExpandedSections()
        }
    }

    // MARK: - Section card

    private func sectionCard(_ section: DaySection, date: Date) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems(for: date))
        let deadlines = viewModel.deadlineRows(section, from: activeItems(for: date))
        let allSectionItems = pills + deadlines
        let rawAll = viewModel.sectionPills(section, from: rawItems(for: date))
                   + viewModel.deadlineRows(section, from: rawItems(for: date))
        let completed = rawAll.filter { $0.status == .completed }.count
        let total = rawAll.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let isCurrent = viewModel.currentSection == section && Calendar.current.isDateInToday(date)
        let allDone = total > 0 && completed == total
        let expanded = expandedSections.contains(section)

        return VStack(alignment: .leading, spacing: 0) {
            if expanded {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        _ = expandedSections.remove(section)
                    }
                } label: {
                    cardHeader(
                        title: section.displayName,
                        subtitle: section.timeRangeLabel,
                        completed: completed, total: total, pct: pct,
                        isCurrent: isCurrent, allDone: allDone
                    )
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    addingToSection = section
                    addingItemForDate = date
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                }
                .buttonStyle(.plain)

                if allSectionItems.isEmpty {
                    Text("Nothing scheduled")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if !pills.isEmpty {
                            HFlow(spacing: 8) {
                                ForEach(pills) { item in
                                    ItemPillView(item: item)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        if !pills.isEmpty && !deadlines.isEmpty {
                            Divider()
                        }
                        ForEach(deadlines) { item in
                            cardDeadlineRow(item)
                            if item.id != deadlines.last?.id {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            } else {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        _ = expandedSections.insert(section)
                    }
                } label: {
                    collapsedSectionHeader(
                        section: section,
                        completed: completed, total: total,
                        isCurrent: isCurrent, allDone: allDone
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background { RoundedRectangle(cornerRadius: 18).fill(.background) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isCurrent ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2),
                        lineWidth: isCurrent ? 1.5 : 0.5)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .onAppear {
            if !allSectionItems.isEmpty {
                viewModel.generateSummaryIfNeeded(for: section, items: allSectionItems, events: [], reminders: [])
            }
        }
    }

    @ViewBuilder
    private func openCard(_ items: [PlanItem], date: Date) -> some View {
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0

        VStack(alignment: .leading, spacing: 0) {
            cardHeader(
                title: "Open",
                subtitle: "no specific time",
                completed: completed, total: total, pct: pct,
                isCurrent: false, allDone: total > 0 && completed == total
            )

            Divider()

            Button {
                addingItemForDate = date
                isAddingItem = true
            } label: {
                Label("Add item", systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            }
            .buttonStyle(.plain)

            HFlow(spacing: 8) {
                ForEach(items) { item in
                    ItemPillView(item: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Card headers

    private func cardHeader(
        title: String,
        subtitle: String,
        completed: Int,
        total: Int,
        pct: Double,
        isCurrent: Bool,
        allDone: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    Spacer()
                }

                HStack(spacing: 5) {
                    if isCurrent {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("NOW  ·")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.15), lineWidth: 6)
                if total > 0 {
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(
                            allDone ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.4), value: completed)
                }
                Text("\(completed)/\(total)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(allDone && total > 0 ? Color.green : Color.secondary)
            }
            .frame(width: 56, height: 56)
        }
        .padding(16)
        .background(isCurrent ? Color.accentColor.opacity(0.04) : Color.clear)
    }

    private func collapsedSectionHeader(
        section: DaySection,
        completed: Int,
        total: Int,
        isCurrent: Bool,
        allDone: Bool
    ) -> some View {
        let summary = viewModel.sectionSummaries[section]
        let isLoading = viewModel.loadingSummarySections.contains(section)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(section.displayName)
                        .font(.headline)
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(section.timeRangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isCurrent {
                        Circle().fill(.red).frame(width: 5, height: 5)
                        Text("NOW")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }

                if let summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if isLoading {
                    loadingDotsView
                } else if allDone && total > 0 {
                    Text("All done ✓")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if total > 0 {
                    Text("\(total - completed) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nothing scheduled")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if total > 0 {
                Text(allDone ? "✓" : "\(completed)/\(total)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(allDone ? .green : .secondary)
            }
        }
        .padding(16)
        .background(isCurrent ? Color.accentColor.opacity(0.04) : Color.clear)
        .frame(maxWidth: .infinity)
    }

    private var loadingDotsView: some View {
        Text("···")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .phaseAnimator([1.0, 0.3]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
    }

    // MARK: - Row types

    private func cardRow(_ item: PlanItem) -> some View {
        HStack(spacing: 14) {
            Button {
                guard item.status != .canceled else { return }
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    switch item.status {
                    case .completed:
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    case .canceled:
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    case .pending:
                        EmptyView()
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(item.status == .canceled)

            Text(item.title)
                .font(.body)
                .strikethrough(item.status == .completed)
                .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if item.isFlagged {
                    Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
                }
                if item.isRecurring {
                    Image(systemName: "infinity").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
    }

    private func cardDeadlineRow(_ item: PlanItem) -> some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if item.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                    .strikethrough(item.status == .completed)
                    .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                if let dl = item.deadline {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2)
                        Text(dl, format: .dateTime.hour().minute())
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isFlagged {
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
    }

    // MARK: - Category selector sheet

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
    FlightPlanView(viewModel: DayViewModel(), onShowSettings: {})
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
