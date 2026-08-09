//
//  GridOverviewView.swift
//  DailyFlightPlan
//
//  Dashboard overview: 2-column section tiles with AI summaries.
//  The current time section is shown as a full-width interactive card.
//  Open items also get a full-width interactive card.
//  Tapping a tile pushes a full-screen section detail view.
//
import SwiftUI
import SwiftData

struct GridOverviewView: View {

    var viewModel: DayViewModel

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

    @State private var expandedSection: DaySection? = nil
    @State private var itemToEdit: PlanItem? = nil
    @State private var addingToSection: DaySection? = nil
    @State private var isAddingItem = false
    @State private var showCategorySelector = false
    @State private var isShowingCategoriesEdit = false

    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
    }

    private var activeItems: [PlanItem] {
        let filtered = allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate)
            && (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
            && (showRecurring || !$0.isRecurring)
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    // Sections shown in the 2-column grid — excludes current section on today (shown full-width instead)
    private var gridSections: [DaySection] {
        guard viewModel.isToday, let current = viewModel.currentSection else {
            return DaySection.allCases
        }
        return DaySection.allCases.filter { $0 != current }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dateNavHeader
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                    overallProgress

                    // Current section: full-width expanded interactive card (today only)
                    if let current = viewModel.currentSection {
                        currentSectionCard(current)
                            .padding(.horizontal)
                    }

                    // 2-column summary grid
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(gridSections) { section in
                            sectionTile(section)
                        }
                    }
                    .padding(.horizontal)

                    // Open items: full-width interactive card
                    let openItems = viewModel.anyTimeItems(from: activeItems)
                    if !openItems.isEmpty {
                        openCard(openItems)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 80)
                }
            }
            .safeAreaInset(edge: .bottom) { addButton }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(item: $expandedSection) { section in
                GridSectionDetailView(section: section, viewModel: viewModel)
            }
        }
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
        .sheet(isPresented: $isAddingItem) { ItemForm(date: viewModel.selectedDate) }
        .sheet(isPresented: Binding(
            get: { addingToSection != nil },
            set: { if !$0 { addingToSection = nil } }
        )) {
            if let section = addingToSection {
                ItemForm(date: viewModel.selectedDate, section: section)
            }
        }
        .sheet(isPresented: $showCategorySelector) { categorySelectorSheet }
        .sheet(isPresented: $isShowingCategoriesEdit) { CategoriesEditView() }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
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
    }

    // MARK: Date navigation header

    private var dateNavHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToYesterday() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(viewModel.selectedDate, format: .dateTime.month(.abbreviated).day())
                        .font(.title2.bold()).monospacedDigit()
                    if !viewModel.isToday {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToToday() }
                        } label: {
                            Image(systemName: "scope").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Go to Today")
                    }
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToTomorrow() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Overall progress

    @ViewBuilder
    private var overallProgress: some View {
        let total = activeItems.count
        let done = activeItems.filter { $0.status == .completed }.count
        if total > 0 {
            HStack(spacing: 8) {
                ProgressRingView(
                    progress: Double(done) / Double(total),
                    completed: done,
                    total: total
                )
                Text("\(done) of \(total) complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    // MARK: Current section card (full-width, interactive)

    private func currentSectionCard(_ section: DaySection) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems)
        let deadlines = viewModel.deadlineRows(section, from: activeItems)
        let all = pills + deadlines
        let completed = all.filter { $0.status == .completed }.count
        let total = all.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let allDone = total > 0 && completed == total

        return VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("NOW  ·  \(section.timeRangeLabel)")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                    Text(section.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(Color.accentColor)
                    Button { addingToSection = section } label: {
                        Label("Add item", systemImage: "plus")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer()

                ringView(completed: completed, total: total, pct: pct, allDone: allDone, size: 56, lineWidth: 6)
            }
            .padding(14)
            .background(Color.accentColor.opacity(0.04))

            if !all.isEmpty {
                Divider()
                VStack(spacing: 0) {
                    ForEach(pills) { item in
                        interactiveRow(item)
                        if item.id != pills.last?.id || !deadlines.isEmpty {
                            Divider().padding(.leading, 54)
                        }
                    }
                    ForEach(deadlines) { item in
                        interactiveDeadlineRow(item)
                        if item.id != deadlines.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
        }
        .shadow(color: Color.accentColor.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    // MARK: Summary tile (compact, AI summary, tappable)

    private func sectionTile(_ section: DaySection) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems)
        let deadlines = viewModel.deadlineRows(section, from: activeItems)
        let all = pills + deadlines
        let completed = all.filter { $0.status == .completed }.count
        let total = all.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let allDone = total > 0 && completed == total
        let summary = viewModel.sectionSummaries[section]
        let isLoading = viewModel.loadingSummarySections.contains(section)

        return Button { expandedSection = section } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(section.displayName)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ringView(completed: completed, total: total, pct: pct, allDone: allDone, size: 28, lineWidth: 4)
                }

                Group {
                    if let summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if isLoading {
                        loadingDotsView
                    } else if total == 0 {
                        Text("Nothing scheduled")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(all.prefix(3))) { item in
                                itemPreviewRow(item)
                            }
                            if all.count > 3 {
                                Text("+\(all.count - 3) more")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Text(section.timeRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if !all.isEmpty {
                viewModel.generateSummaryIfNeeded(for: section, items: all, events: [], reminders: [])
            }
        }
    }

    // MARK: Open card (full-width, interactive)

    private func openCard(_ items: [PlanItem]) -> some View {
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let allDone = total > 0 && completed == total

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open")
                        .font(.title2.bold())
                    Text("no specific time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button { isAddingItem = true } label: {
                        Label("Add item", systemImage: "plus")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer()

                ringView(completed: completed, total: total, pct: pct, allDone: allDone, size: 56, lineWidth: 6)
            }
            .padding(14)

            Divider()

            VStack(spacing: 0) {
                ForEach(items) { item in
                    interactiveRow(item)
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 54)
                    }
                }
            }
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

    // MARK: Shared ring view

    private func ringView(completed: Int, total: Int, pct: Double, allDone: Bool, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.15), lineWidth: lineWidth)
            if total > 0 {
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(allDone ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.4), value: completed)
            }
            if allDone {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(.green)
            } else if total > 0 {
                Text("\(completed)/\(total)")
                    .font(.system(size: size * 0.22).monospacedDigit().bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: Interactive rows

    private func interactiveRow(_ item: PlanItem) -> some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                    if item.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.body)
                .strikethrough(item.status == .completed)
                .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if item.isFlagged { Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange) }
                if item.isRecurring { Image(systemName: "infinity").font(.caption2).foregroundStyle(.secondary) }
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

    private func interactiveDeadlineRow(_ item: PlanItem) -> some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.3),
                                lineWidth: 1.5)
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
                        Text(dl, format: .dateTime.hour().minute()).font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isFlagged { Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange) }
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

    // MARK: Helper views

    private func itemPreviewRow(_ item: PlanItem) -> some View {
        let icon = item.status == .completed ? "checkmark.circle.fill" : "circle"
        let iconColor: Color = item.status == .completed ? .accentColor : Color.secondary.opacity(0.4)
        let textColor: Color = item.status == .completed ? .secondary : .primary
        return HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(iconColor)
            Text(item.title).font(.caption).foregroundStyle(textColor).lineLimit(1)
        }
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

    private var addButton: some View {
        Button { isAddingItem = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add Item")
            }
            .font(.body.bold())
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.bottom, 8)
    }

    // MARK: Category selector sheet

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

// MARK: - Section detail view (full-screen navigation push)

private struct GridSectionDetailView: View {

    let section: DaySection
    var viewModel: DayViewModel

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue) private var showFlaggedOnly = false
    @AppStorage(AppStorageKeys.showCompleted.rawValue) private var showCompleted = false
    @AppStorage(AppStorageKeys.showRecurring.rawValue) private var showRecurring = true

    @Environment(\.categorySelectionService) private var categorySelectionService
    @Environment(\.modelContext) private var modelContext

    @State private var itemToEdit: PlanItem? = nil
    @State private var isAddingItem = false

    private var items: [PlanItem] {
        let filtered = allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate)
            && (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
            && (showRecurring || !$0.isRecurring)
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    private var sectionPills: [PlanItem] { viewModel.sectionPills(section, from: items) }
    private var sectionDeadlines: [PlanItem] { viewModel.deadlineRows(section, from: items) }
    private var allSectionItems: [PlanItem] { sectionPills + sectionDeadlines }

    var body: some View {
        let completed = allSectionItems.filter { $0.status == .completed }.count
        let total = allSectionItems.count

        return List {
            Section {
                ForEach(sectionPills) { item in pillRow(item) }
                ForEach(sectionDeadlines) { item in deadlineRow(item) }
                if allSectionItems.isEmpty {
                    Text("Nothing scheduled")
                        .foregroundStyle(.tertiary)
                        .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text(section.timeRangeLabel)
                    Spacer()
                    if total > 0 {
                        Text("\(completed) of \(total) complete")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .navigationTitle(section.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAddingItem = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Item")
            }
        }
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(isPresented: $isAddingItem) {
            ItemForm(date: viewModel.selectedDate, section: section)
        }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
    }

    private func pillRow(_ item: PlanItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .strikethrough(item.status == .completed)
                .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if item.isFlagged {
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
        }
    }

    private func deadlineRow(_ item: PlanItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.status == .completed)
                    .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                if let dl = item.deadline {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2)
                        Text(dl, format: .dateTime.hour().minute()).font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isFlagged {
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
        }
    }
}

#Preview {
    GridOverviewView(viewModel: DayViewModel())
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
