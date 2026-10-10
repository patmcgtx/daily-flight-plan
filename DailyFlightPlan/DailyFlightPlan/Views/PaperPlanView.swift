//
//  PaperPlanView.swift
//  DailyFlightPlan
//
// Design-sprint tab: identical functionality and layout to FlightPlanView, restyled with the
// "Paper Plan" look (monospaced type, flat black borders, hard offset shadows, highlighter-yellow
// accents) — see Theming/PaperPlanStyle.swift. Flagged items are called out with a yellow
// highlighter behind the title instead of a flag icon.
import SwiftUI
import SwiftData
import Flow

struct PaperPlanView: View {

    var viewModel: DayViewModel
    var calendarEvents: [CalendarEvent] = []
    var reminderItems: [ReminderItem] = []
    var isDeletingData: Bool = false
    let onShowSettings: () -> Void
    let onShowImport: () -> Void

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue)
    private var showFlaggedOnly: Bool = false

    @AppStorage(AppStorageKeys.showCompleted.rawValue)
    private var showCompleted: Bool = false

    @AppStorage(AppStorageKeys.showRecurring.rawValue)
    private var showRecurring: Bool = true

    @AppStorage(AppStorageKeys.showCalendarEvents.rawValue)
    private var showCalendarEvents: Bool = true

    @AppStorage(AppStorageKeys.showReminderItems.rawValue)
    private var showReminderItems: Bool = true

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
    @State private var expandedSections: Set<DaySection> = []
    @State private var dropTargetedSection: DaySection? = nil
    @State private var isOpenDropTargeted = false

    @State private var searchText: String = ""
    @State private var isShowingSearch = false
    @FocusState private var isSearchFieldFocused: Bool

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (categorySelectionService?.hasSelectedCategories ?? false)
    }

    var body: some View {
        NavigationStack {
            swipeableContent
                .background(PaperPlanStyle.background)
                .safeAreaInset(edge: .top) {
                    if isShowingSearch {
                        InlineSearchField(text: $searchText, isFocused: $isSearchFieldFocused)
                    }
                }
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .leadingBar) {
                        Button { onShowSettings() } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }

                    ToolbarItem(placement: .leadingBar) {
                        Button { onShowImport() } label: {
                            Image(systemName: "arrow.down.doc")
                        }
                        .accessibilityLabel("Import Items")
                    }

                    ToolbarItemGroup(placement: .trailingBar) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToToday() }
                        } label: {
                            Image(systemName: "scope")
                        }
                        .disabled(viewModel.isToday)
                        .accessibilityLabel("Go to Today")

                        SearchToggleButton(
                            isShowingSearch: $isShowingSearch, searchText: $searchText,
                            isFocused: $isSearchFieldFocused
                        )

                        FilterToolbarButton(activeTab: .flightDeck)

                        Menu {
                            ForEach(DFPTheme.allCases) { option in
                                Button { theme = option } label: {
                                    Label(option.localizedName, systemImage: option.menuIconName)
                                }
                            }
                        } label: {
                            Image(systemName: theme.menuIconName)
                                .foregroundStyle(theme == .cupertino ? PaperPlanStyle.ink : Color.accentColor)
                        }
                        .accessibilityLabel("Theme")
                    }
                }
        }
        .tint(PaperPlanStyle.ink)
        .overlay(alignment: .bottomTrailing) {
            Button { isAddingItem = true } label: {
                Image(systemName: "plus")
                    .font(.title2)
            }
            .buttonStyle(.glass)
            .tint(PaperPlanStyle.highlighter)
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .padding(.trailing, 16)
            .padding(.bottom, 16)
            .accessibilityLabel("Add Item")
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
        let isSelectedDate = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
        let categoriesActive = categorySelectionService?.hasSelectedCategories ?? false
        let visibleEvents = searchFiltered(events:
            (showCalendarEvents && !categoriesActive && isSelectedDate) ? calendarEvents : []
        )
        let rawReminders = (showReminderItems && !categoriesActive && isSelectedDate) ? reminderItems : []
        let visibleReminders = searchFiltered(reminders:
            showCompleted ? rawReminders : rawReminders.filter { !$0.isCompleted }
        )
        let items = activeItems(for: date)
        let raw = rawItems(for: date)

        ScrollView {
            VStack(spacing: 16) {
                dayLabel(for: date)

                ForEach(DaySection.allCases) { section in
                    sectionCard(
                        section, date: date, items: items, raw: raw,
                        events: viewModel.calendarEventsForSection(section, from: visibleEvents),
                        reminders: viewModel.reminderItemsForSection(section, from: visibleReminders)
                    )
                }

                let openItems = viewModel.anyTimeItems(from: items)
                let anyTimeReminders = viewModel.anyTimeReminderItems(from: visibleReminders)
                if !openItems.isEmpty || !anyTimeReminders.isEmpty {
                    openCard(openItems, date: date, anyTimeReminders: anyTimeReminders)
                }

                progressRow(raw)

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PaperPlanStyle.background)
    }

    private func progressRow(_ items: [PlanItem]) -> some View {
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0
        return HStack(spacing: 12) {
            ProgressRingView(progress: progress, completed: completed, total: total)
            if total == 0 {
                Text("No items planned")
                    .font(PaperPlanStyle.mono(.subheadline))
                    .foregroundStyle(PaperPlanStyle.muted)
            } else if completed == total {
                Text("All done!")
                    .font(PaperPlanStyle.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.green)
            } else {
                Text("\(completed) of \(total) complete")
                    .font(PaperPlanStyle.mono(.subheadline))
                    .foregroundStyle(PaperPlanStyle.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func dayLabel(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        return VStack(spacing: 2) {
            Text(isToday ? "Today" : date.formatted(.dateTime.weekday(.wide)))
                .font(PaperPlanStyle.mono(.subheadline, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(isToday ? PaperPlanStyle.ink : PaperPlanStyle.muted)
                .padding(.horizontal, isToday ? 6 : 0)
                .padding(.vertical, isToday ? 2 : 0)
                .background(isToday ? PaperPlanStyle.highlighter : Color.clear)
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(PaperPlanStyle.mono(.title2, weight: .bold))
                .foregroundStyle(PaperPlanStyle.ink)
        }
        .padding(.vertical, 8)
    }

    private func activeItems(for date: Date) -> [PlanItem] {
        guard !isDeletingData else { return [] }
        let sameDay = allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let filtered = sameDay
            .matchingDayStatusFilters(
                showFlaggedOnly: showFlaggedOnly, showCompleted: showCompleted, showRecurring: showRecurring
            )
            .matchingSearchText(searchText)
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    private func searchFiltered(events: [CalendarEvent]) -> [CalendarEvent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return events }
        return events.filter { $0.title.localizedStandardContains(query) }
    }

    private func searchFiltered(reminders: [ReminderItem]) -> [ReminderItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return reminders }
        return reminders.filter {
            $0.title.localizedStandardContains(query) || ($0.notes?.localizedStandardContains(query) ?? false)
        }
    }

    private func rawItems(for date: Date) -> [PlanItem] {
        guard !isDeletingData else { return [] }
        return allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
            && $0.status != .canceled
        }
    }

    private var filterKey: String {
        let cats = categorySelectionService?.selectedNames.sorted().joined() ?? ""
        let mode = categorySelectionService?.filterMode.rawValue ?? ""
        return "\(showFlaggedOnly)-\(showCompleted)-\(showRecurring)-\(searchText)-\(cats)-\(mode)"
    }

    private func initializeExpandedSections() {
        expandedSections = []
        if let current = viewModel.currentSection, viewModel.isToday {
            expandedSections = [current]
        }
    }

    private func applyFilterToExpandedSections() {
        if isFilterActive {
            let categoriesActive = categorySelectionService?.hasSelectedCategories ?? false
            let visibleEvents = searchFiltered(events:
                (showCalendarEvents && !categoriesActive) ? calendarEvents : []
            )
            let rawReminders = (showReminderItems && !categoriesActive) ? reminderItems : []
            let visibleReminders = searchFiltered(reminders:
                showCompleted ? rawReminders : rawReminders.filter { !$0.isCompleted }
            )
            let selectedItems = activeItems(for: viewModel.selectedDate)
            expandedSections = Set(DaySection.allCases.filter { section in
                let items = viewModel.sectionPills(section, from: selectedItems)
                           + viewModel.deadlineRows(section, from: selectedItems)
                let events = viewModel.calendarEventsForSection(section, from: visibleEvents)
                let reminders = viewModel.reminderItemsForSection(section, from: visibleReminders)
                return !items.isEmpty || !events.isEmpty || !reminders.isEmpty
            })
        } else {
            initializeExpandedSections()
        }
    }

    private func handlePillDrop(uuidString: String, targetSection: DaySection?) {
        guard let uuid = UUID(uuidString: uuidString),
              let item = allItems.first(where: { $0.uuid == uuid }) else { return }
        guard item.daySection != targetSection || item.deadline != nil else { return }
        withAnimation(.spring(duration: 0.3)) {
            item.daySection = targetSection
            item.deadline = nil
        }
        try? modelContext.save()
    }

    // MARK: - Section card

    private func sectionCard(
        _ section: DaySection,
        date: Date,
        items: [PlanItem],
        raw: [PlanItem],
        events: [CalendarEvent],
        reminders: [ReminderItem]
    ) -> some View {
        let pills = viewModel.sectionPills(section, from: items)
        let regularPills = pills.filter { !$0.isRecurring }
        let routinePills = pills.filter { $0.isRecurring }
        let deadlines = viewModel.deadlineRows(section, from: items)
        let allSectionItems = pills + deadlines
        let hasContent = !allSectionItems.isEmpty || !events.isEmpty || !reminders.isEmpty
        let contentSignature = viewModel.contentSignature(items: allSectionItems, events: events, reminders: reminders)
        let isSelectedDate = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
        let rawAll = viewModel.sectionPills(section, from: raw) + viewModel.deadlineRows(section, from: raw)
        let completed = rawAll.filter { $0.status == .completed }.count
        let total = rawAll.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let isCurrent = viewModel.currentSection == section && Calendar.current.isDateInToday(date)
        let allDone = total > 0 && completed == total
        let hasOverdue: Bool = {
            guard Calendar.current.isDateInToday(date) else { return false }
            let comps = Calendar.current.dateComponents([.hour, .minute], from: .now)
            let nowMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            return nowMinutes > section.endMinutes && rawAll.contains { $0.status == .pending }
        }()
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
                        hasOverdue: hasOverdue
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Rectangle().fill(PaperPlanStyle.border).frame(height: 1)

                Button {
                    addingToSection = section
                    addingItemForDate = date
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(PaperPlanStyle.mono(.caption, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(PaperPlanStyle.ink)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                }
                .buttonStyle(.plain)

                if !hasContent {
                    Text("Nothing scheduled")
                        .font(PaperPlanStyle.mono(.subheadline))
                        .foregroundStyle(PaperPlanStyle.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if !regularPills.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "calendar.day.timeline.left")
                                    .font(.caption)
                                    .foregroundStyle(PaperPlanStyle.muted)
                                    .frame(width: 16)
                                    .padding(.top, 7)
                                HFlow(spacing: 8) {
                                    ForEach(regularPills) { item in
                                        paperPill(item)
                                            .draggable(item.uuid.uuidString)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, routinePills.isEmpty ? 10 : 6)
                        }
                        if !routinePills.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "infinity")
                                    .font(.caption)
                                    .foregroundStyle(PaperPlanStyle.muted)
                                    .frame(width: 16)
                                    .padding(.top, 7)
                                HFlow(spacing: 8) {
                                    ForEach(routinePills) { item in
                                        paperPill(item, showRecurringBadge: false)
                                            .draggable(item.uuid.uuidString)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, regularPills.isEmpty ? 10 : 0)
                            .padding(.bottom, 10)
                        }
                        if !pills.isEmpty && !deadlines.isEmpty {
                            Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1)
                        }
                        ForEach(deadlines) { item in
                            cardDeadlineRow(item)
                            if item.id != deadlines.last?.id {
                                Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1).padding(.leading, 54)
                            }
                        }
                        if !events.isEmpty {
                            if !allSectionItems.isEmpty { Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1) }
                            VStack(spacing: 0) {
                                ForEach(events) { event in
                                    CalendarEventRow(event: event)
                                }
                            }
                        }
                        if !reminders.isEmpty {
                            if !allSectionItems.isEmpty || !events.isEmpty {
                                Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1)
                            }
                            VStack(spacing: 0) {
                                ForEach(reminders) { reminder in
                                    ReminderItemRow(item: reminder)
                                }
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
                        isCurrent: isCurrent, allDone: allDone,
                        hasOverdue: hasOverdue
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .background { Rectangle().fill(PaperPlanStyle.surface) }
        .clipShape(Rectangle())
        .overlay {
            let isDropTargeted = dropTargetedSection == section
            Rectangle()
                .stroke(
                    isDropTargeted ? PaperPlanStyle.highlighter : PaperPlanStyle.border,
                    lineWidth: isDropTargeted ? 3 : isCurrent ? 2.5 : 1.5
                )
        }
        .background {
            Rectangle().fill(PaperPlanStyle.shadow).offset(x: 3, y: 4)
        }
        .dropDestination(for: String.self) { dropItems, _ in
            guard let uuidString = dropItems.first else { return false }
            handlePillDrop(uuidString: uuidString, targetSection: section)
            return true
        } isTargeted: { targeted in
            dropTargetedSection = targeted ? section : nil
        }
        .animation(.easeInOut(duration: 0.15), value: dropTargetedSection == section)
        .onAppear {
            guard isSelectedDate else { return }
            if hasContent {
                viewModel.refreshSummaryIfNeeded(for: section, items: allSectionItems, events: events, reminders: reminders)
            }
        }
        .onChange(of: contentSignature) { _, _ in
            guard isSelectedDate else { return }
            if hasContent {
                viewModel.refreshSummaryIfNeeded(for: section, items: allSectionItems, events: events, reminders: reminders)
            } else {
                viewModel.clearSummary(for: section)
            }
        }
    }

    @ViewBuilder
    private func openCard(_ items: [PlanItem], date: Date, anyTimeReminders: [ReminderItem]) -> some View {
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

            Rectangle().fill(PaperPlanStyle.border).frame(height: 1)

            Button {
                addingItemForDate = date
                isAddingItem = true
            } label: {
                Label("Add item", systemImage: "plus")
                    .font(PaperPlanStyle.mono(.caption, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(PaperPlanStyle.ink)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            }
            .buttonStyle(.plain)

            if !items.isEmpty {
                HFlow(spacing: 8) {
                    ForEach(items) { item in
                        paperPill(item)
                            .draggable(item.uuid.uuidString)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            if !anyTimeReminders.isEmpty {
                if !items.isEmpty { Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1) }
                VStack(spacing: 0) {
                    ForEach(anyTimeReminders) { reminder in
                        ReminderItemRow(item: reminder)
                    }
                }
            }
        }
        .padding(.bottom, 4)
        .background(PaperPlanStyle.surface)
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(isOpenDropTargeted ? PaperPlanStyle.highlighter : PaperPlanStyle.border,
                        lineWidth: isOpenDropTargeted ? 3 : 1.5)
        }
        .background {
            Rectangle().fill(PaperPlanStyle.shadow).offset(x: 3, y: 4)
        }
        .dropDestination(for: String.self) { dropItems, _ in
            guard let uuidString = dropItems.first else { return false }
            handlePillDrop(uuidString: uuidString, targetSection: nil)
            return true
        } isTargeted: { targeted in
            isOpenDropTargeted = targeted
        }
        .animation(.easeInOut(duration: 0.15), value: isOpenDropTargeted)
    }

    // MARK: - Card headers

    private func cardHeader(
        title: String,
        subtitle: String,
        completed: Int,
        total: Int,
        pct: Double,
        isCurrent: Bool,
        allDone: Bool,
        hasOverdue: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(PaperPlanStyle.mono(.title2, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(isCurrent ? PaperPlanStyle.ink : PaperPlanStyle.ink.opacity(0.85))
                    Spacer()
                }

                HStack(spacing: 5) {
                    if isCurrent {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("NOW  ·")
                            .font(PaperPlanStyle.mono(.caption, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    Text(subtitle)
                        .font(PaperPlanStyle.mono(.caption))
                        .textCase(.uppercase)
                        .foregroundStyle(PaperPlanStyle.muted)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(PaperPlanStyle.border.opacity(0.25), lineWidth: 6)
                if total > 0 {
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(
                            allDone ? Color.green : PaperPlanStyle.ink,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.4), value: completed)
                }
                Text(hasOverdue ? "! \(completed)/\(total)" : "\(completed)/\(total)")
                    .font(PaperPlanStyle.mono(.caption2, weight: .bold))
                    .foregroundStyle(allDone && total > 0 ? Color.green : hasOverdue ? Color.orange : PaperPlanStyle.muted)
            }
            .frame(width: 56, height: 56)
        }
        .padding(16)
        .background(isCurrent ? PaperPlanStyle.highlighter.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
    }

    private func collapsedSectionHeader(
        section: DaySection,
        completed: Int,
        total: Int,
        isCurrent: Bool,
        allDone: Bool,
        hasOverdue: Bool = false
    ) -> some View {
        let summary = viewModel.sectionSummaries[section]
        let isLoading = viewModel.loadingSummarySections.contains(section)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(section.displayName)
                        .font(PaperPlanStyle.mono(.headline, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(PaperPlanStyle.ink)
                    Text("·")
                        .font(PaperPlanStyle.mono(.caption))
                        .foregroundStyle(PaperPlanStyle.muted)
                    Text(section.timeRangeLabel)
                        .font(PaperPlanStyle.mono(.caption))
                        .textCase(.uppercase)
                        .foregroundStyle(PaperPlanStyle.muted)
                    if isCurrent {
                        Circle().fill(.red).frame(width: 5, height: 5)
                        Text("NOW")
                            .font(PaperPlanStyle.mono(.caption, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }

                if let summary {
                    Text(summary)
                        .font(PaperPlanStyle.mono(.caption))
                        .foregroundStyle(PaperPlanStyle.muted)
                        .lineLimit(2)
                } else if isLoading {
                    loadingDotsView
                } else if allDone && total > 0 {
                    Text("All done ✓")
                        .font(PaperPlanStyle.mono(.caption))
                        .foregroundStyle(.green)
                } else if total > 0 {
                    Text("\(total - completed) remaining")
                        .font(PaperPlanStyle.mono(.caption))
                        .foregroundStyle(PaperPlanStyle.muted)
                } else {
                    Text("Nothing scheduled")
                        .font(PaperPlanStyle.mono(.caption))
                        .foregroundStyle(PaperPlanStyle.muted)
                }
            }

            Spacer()

            if total > 0 {
                Text(allDone ? "✓ \(completed)/\(total)" : hasOverdue ? "! \(completed)/\(total)" : "\(completed)/\(total)")
                    .font(PaperPlanStyle.mono(.caption2, weight: .bold))
                    .foregroundStyle(allDone ? .green : hasOverdue ? Color.orange : PaperPlanStyle.muted)
            }
        }
        .padding(16)
        .background(isCurrent ? PaperPlanStyle.highlighter.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
    }

    private var loadingDotsView: some View {
        Text("···")
            .font(PaperPlanStyle.mono(.caption))
            .foregroundStyle(PaperPlanStyle.muted)
            .phaseAnimator([1.0, 0.3]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
    }

    // MARK: - Row types

    /// A flagged item is called out with a highlighter-yellow background behind its title
    /// instead of a flag icon — the one deliberate behavior swap for this design sprint.
    private func paperPill(_ item: PlanItem, showRecurringBadge: Bool = true) -> some View {
        HStack(spacing: 5) {
            if item.status == .pending {
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        item.status = .completed
                    }
                } label: {
                    Image(systemName: "circle")
                        .foregroundStyle(PaperPlanStyle.muted)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            Text(item.title)
                .font(PaperPlanStyle.mono(.subheadline, weight: .semibold))
                .textCase(.uppercase)
                .lineLimit(1)
                .foregroundStyle(item.status == .pending ? PaperPlanStyle.ink : PaperPlanStyle.muted)
                .strikethrough(item.status != .pending, color: PaperPlanStyle.muted)
                .padding(.horizontal, item.isFlagged ? 3 : 0)
                .background(item.isFlagged ? PaperPlanStyle.highlighter.opacity(0.8) : Color.clear)

            if !item.notes.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption2)
                    .foregroundStyle(PaperPlanStyle.muted)
            }
            if item.isRecurring && showRecurringBadge {
                Image(systemName: "infinity")
                    .font(.caption2)
                    .foregroundStyle(PaperPlanStyle.muted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Rectangle().stroke(PaperPlanStyle.border, lineWidth: 1)
        }
        .onTapGesture { itemToEdit = item }
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { item.status = .canceled }
            } label: {
                Label("Cancel Item", systemImage: "xmark.circle")
            }
            if !item.isRecurring {
                Button {
                    let cal = Calendar.current
                    let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: item.date))!
                    item.date = tomorrow
                    if let deadline = item.deadline {
                        item.deadline = cal.date(byAdding: .day, value: 1, to: deadline)
                    }
                } label: {
                    Label("Defer to Tomorrow", systemImage: "arrow.right.circle")
                }
            }
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
                            item.status == .completed ? PaperPlanStyle.routeBlue : PaperPlanStyle.border.opacity(0.5),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if item.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(PaperPlanStyle.routeBlue)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(PaperPlanStyle.mono(.body, weight: .semibold))
                    .textCase(.uppercase)
                    .strikethrough(item.status == .completed)
                    .foregroundStyle(item.status == .completed ? PaperPlanStyle.muted : PaperPlanStyle.ink)
                    .padding(.horizontal, item.isFlagged ? 3 : 0)
                    .background(item.isFlagged ? PaperPlanStyle.highlighter.opacity(0.8) : Color.clear)
                if let dl = item.deadline {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2)
                        Text(dl, format: .dateTime.hour().minute())
                            .font(PaperPlanStyle.mono(.caption2))
                    }
                    .foregroundStyle(PaperPlanStyle.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

}

#if DEBUG

#Preview {
    PaperPlanView(viewModel: DayViewModel(), onShowSettings: {}, onShowImport: {})
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#endif
