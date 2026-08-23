//
//  CardDeckView.swift
//  DailyFlightPlan
//
//  All day sections as vertically stacked cards in one continuous scroll.
//  Each card keeps the large-header + progress ring look from the original design.
//
import SwiftUI
import SwiftData

struct CardDeckView: View {

    var viewModel: DayViewModel
    var isDeletingData: Bool = false

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

    @State private var itemToEdit: PlanItem?
    @State private var addingToSection: DaySection? = nil
    @State private var isAddingItem = false
    @State private var showCategorySelector = false
    @State private var isShowingCategoriesEdit = false
    @State private var expandedSections: Set<DaySection> = []

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
    }

    private var activeItems: [PlanItem] {
        guard !isDeletingData else { return [] }
        let filtered = allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate)
            && (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
            && (showRecurring || !$0.isRecurring)
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dateNavHeader

                    ForEach(DaySection.allCases) { section in
                        sectionCard(section)
                    }

                    let openItems = viewModel.anyTimeItems(from: activeItems)
                    if !openItems.isEmpty {
                        openCard(openItems)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .inlineNavigationTitle()
            .toolbar {
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
            .onAppear { initializeExpandedSections() }
            .onChange(of: viewModel.selectedDate) { initializeExpandedSections() }
        }
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(isPresented: $isAddingItem) { ItemForm(date: viewModel.selectedDate) }
        .sheet(isPresented: Binding(
            get: { addingToSection != nil },
            set: { if !$0 { addingToSection = nil } }
        )) {
            if let section = addingToSection {
                ItemForm(date: viewModel.selectedDate, section: section)
            }
        }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
        .sheet(isPresented: $showCategorySelector) { categorySelectorSheet }
        .sheet(isPresented: $isShowingCategoriesEdit) {
            CategoriesEditView(allCategories: allCategories)
                .environment(\.modelContext, modelContext)
        }
    }

    private func initializeExpandedSections() {
        expandedSections = []
        if let current = viewModel.currentSection, viewModel.isToday {
            expandedSections = [current]
        }
    }

    // MARK: Date navigation header

    private var dateNavHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToYesterday() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.subheadline).foregroundStyle(.secondary)
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
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
        }
        .padding(.vertical, 8)
    }

    // MARK: Section card

    private func sectionCard(_ section: DaySection) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems)
        let deadlines = viewModel.deadlineRows(section, from: activeItems)
        let allSectionItems = pills + deadlines
        let completed = allSectionItems.filter { $0.status == .completed }.count
        let total = allSectionItems.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let isCurrent = viewModel.currentSection == section && viewModel.isToday
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
                        isCurrent: isCurrent, allDone: allDone,
                        isExpanded: true
                    )
                }
                .buttonStyle(.plain)

                Divider()

                Button { addingToSection = section } label: {
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
                    VStack(spacing: 0) {
                        ForEach(pills) { item in
                            cardRow(item)
                            if item.id != pills.last?.id || !deadlines.isEmpty {
                                Divider().padding(.leading, 54)
                            }
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
    private func openCard(_ items: [PlanItem]) -> some View {
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0

        VStack(alignment: .leading, spacing: 0) {
            cardHeader(
                title: "Open",
                subtitle: "no specific time",
                completed: completed, total: total, pct: pct,
                isCurrent: false, allDone: total > 0 && completed == total,
                isExpanded: false
            )

            Divider()

            Button { isAddingItem = true } label: {
                Label("Add item", systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    cardRow(item)
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

    // MARK: Card headers

    /// Expanded header — used for section cards (tappable to collapse) and the always-open "Open" card.
    private func cardHeader(
        title: String,
        subtitle: String,
        completed: Int,
        total: Int,
        pct: Double,
        isCurrent: Bool,
        allDone: Bool,
        isExpanded: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    Spacer()
                    if isExpanded {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
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

            // Progress ring
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
                if allDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Text(total > 0 ? "\(completed)/\(total)" : "—")
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
        }
        .padding(16)
        .background(isCurrent ? Color.accentColor.opacity(0.04) : Color.clear)
    }

    /// Collapsed header — tappable to expand.
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
                // Title row
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

                // Summary / loading / fallback
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

            HStack(spacing: 6) {
                if total > 0 {
                    Text(allDone ? "✓" : "\(completed)/\(total)")
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(allDone ? .green : .secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
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

    // MARK: Row types

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

#if DEBUG

#Preview {
    CardDeckView(viewModel: DayViewModel())
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#endif
