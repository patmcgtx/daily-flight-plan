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
            dayContent(for: viewModel.selectedDate)
                .background {
                    PaperPlanStyle.background.ignoresSafeArea()
                }
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
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar, .tabBar)
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

    // MARK: - Day content

    // Day navigation here is via the arrow buttons in `dayLabel`, not swipe — a single
    // ScrollView (not `TabView(.page)`) is used instead of FlightPlanView's 3-page pager so the
    // system can unambiguously track scroll position for Liquid Glass bar transparency/blur. A
    // `TabView(.page)` wrapping multiple ScrollViews confuses that heuristic (see
    // UIViewController's `setContentScrollView(_:for:)` docs), which is what caused the glass
    // bars to show a static backdrop color instead of the day's content scrolling, blurred,
    // behind them.

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

                flightStatusCard(raw, date: date)

                briefingRow(raw, date: date)

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

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            PaperPlanStyle.background.ignoresSafeArea()
        }
    }

    private func dayLabel(for date: Date) -> some View {
        HStack(spacing: 12) {
            dayArrowButton(systemImage: "chevron.left") {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToYesterday() }
            }
            dayLabelText(for: date)
                .frame(maxWidth: .infinity)
            dayArrowButton(systemImage: "chevron.right") {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToTomorrow() }
            }
        }
        .padding(.vertical, 8)
    }

    private func dayArrowButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PaperPlanStyle.ink)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .background(PaperPlanStyle.surface)
        .overlay(Rectangle().stroke(PaperPlanStyle.border, lineWidth: 1.5))
        .background {
            Rectangle().fill(PaperPlanStyle.shadow).offset(x: 2, y: 3)
        }
    }

    private func dayLabelText(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isTomorrow = Calendar.current.isDateInTomorrow(date)
        let isYesterday = Calendar.current.isDateInYesterday(date)
        return VStack(spacing: 4) {
            if isToday {
                Text("Today")
                    .font(PaperPlanStyle.mono(.caption, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PaperPlanStyle.inkOnHighlighter)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(PaperPlanStyle.highlighter)
            } else if isTomorrow || isYesterday {
                Text(isTomorrow ? "Tomorrow" : "Yesterday")
                    .font(PaperPlanStyle.mono(.caption, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PaperPlanStyle.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(PaperPlanStyle.mono(.largeTitle, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(PaperPlanStyle.ink)
            Text(date.formatted(.dateTime.month(.wide).day()))
                .font(PaperPlanStyle.mono(.subheadline))
                .textCase(.uppercase)
                .foregroundStyle(PaperPlanStyle.muted)
        }
    }

    private func flightStatusCard(_ items: [PlanItem], date: Date) -> some View {
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let statusText: String = {
            if total == 0 { return "No items planned" }
            if completed == total { return "All done!" }
            return "Plan active"
        }()

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                paperProgressBox(completed: completed, total: total, pct: pct)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flight Status")
                        .font(PaperPlanStyle.mono(.caption, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(PaperPlanStyle.muted)
                    Text(statusText)
                        .font(PaperPlanStyle.mono(.body, weight: .bold))
                        .foregroundStyle(PaperPlanStyle.ink)
                    if let nextUp = nextUpTime(items, referenceDate: date) {
                        Text("Next up at \(nextUp)")
                            .font(PaperPlanStyle.mono(.caption))
                            .foregroundStyle(PaperPlanStyle.muted)
                    }
                }
                Spacer()
            }
            .padding(14)

            Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1)

            routeIntentionsLine(items)
                .padding(14)
        }
        .background(PaperPlanStyle.surface)
        .overlay(Rectangle().stroke(PaperPlanStyle.border, lineWidth: 1.5))
        .background {
            Rectangle().fill(PaperPlanStyle.shadow).offset(x: 3, y: 4)
        }
    }

    /// "06 ROUTE / INTENTIONS" from the mockup's flight-plan masthead, repurposed as a quick
    /// glance at the day's sections — each section name bolds once every item assigned to it
    /// (pills and deadline rows alike) is completed.
    private func routeIntentionsLine(_ raw: [PlanItem]) -> some View {
        let sections = DaySection.allCases
        let label = Text("ROUTE / INTENTIONS:  ")
            .font(PaperPlanStyle.mono(.caption2, weight: .bold))
            .foregroundColor(PaperPlanStyle.muted)
        let line = sections.enumerated().reduce(label) { partial, entry in
            let (index, section) = entry
            let sectionItems = viewModel.sectionPills(section, from: raw) + viewModel.deadlineRows(section, from: raw)
            let isComplete = !sectionItems.isEmpty && sectionItems.allSatisfy { $0.status == .completed }

            let segment = Text(section.displayName.uppercased())
                .font(PaperPlanStyle.mono(.caption2, weight: isComplete ? .bold : .regular))
                .foregroundColor(isComplete ? PaperPlanStyle.ink : PaperPlanStyle.muted)

            guard index > 0 else { return partial + segment }
            let arrow = Text(" \u{2192} ")
                .font(PaperPlanStyle.mono(.caption2))
                .foregroundColor(PaperPlanStyle.muted)
            return partial + arrow + segment
        }

        return line
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paperProgressBox(completed: Int, total: Int, pct: Double) -> some View {
        let size: CGFloat = 60
        return ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(PaperPlanStyle.ink).frame(width: size * pct)
                Rectangle().fill(PaperPlanStyle.border.opacity(0.25)).frame(width: size * (1 - pct))
            }
            .frame(width: size, height: size)
            Rectangle().fill(PaperPlanStyle.surface).frame(width: size - 10, height: size - 10)
            Rectangle().stroke(PaperPlanStyle.border, lineWidth: 1).frame(width: size, height: size)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(completed)")
                    .font(PaperPlanStyle.mono(.title3, weight: .bold))
                    .foregroundStyle(PaperPlanStyle.ink)
                Text("/\(total)")
                    .font(PaperPlanStyle.mono(.caption2))
                    .foregroundStyle(PaperPlanStyle.muted)
            }
        }
        .frame(width: size, height: size)
    }

    /// The earliest upcoming deadline among this date's pending items — preferring ones still
    /// ahead of the live clock when viewing today, falling back to the day's earliest deadline
    /// otherwise (e.g. a past day, or a today whose remaining deadlines have all slipped by).
    private func nextUpTime(_ items: [PlanItem], referenceDate: Date) -> String? {
        let pendingWithDeadline = items.filter { $0.status == .pending && $0.deadline != nil }
        guard !pendingWithDeadline.isEmpty else { return nil }
        let isToday = Calendar.current.isDateInToday(referenceDate)
        let upcoming = isToday ? pendingWithDeadline.filter { $0.deadline! >= viewModel.currentTime } : pendingWithDeadline
        let pool = upcoming.isEmpty ? pendingWithDeadline : upcoming
        guard let next = pool.min(by: { $0.deadline! < $1.deadline! })?.deadline else { return nil }
        return next.formatted(.dateTime.hour().minute())
    }

    /// A thin rule-bordered strip echoing the mockup's weather/time/priorities "briefing" row —
    /// weather is skipped (no data source for it) in favor of the current time of day. Both the
    /// clock and the countdown tick every second via `TimelineView` rather than the shared
    /// `DayViewModel` clock, which only updates per-minute for the rest of the app.
    private func briefingRow(_ items: [PlanItem], date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let priorityCount = items.filter { $0.isFlagged && $0.status == .pending }.count

        return HStack(spacing: 14) {
            Spacer()
            if isToday {
                SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 14) {
                        briefingItem(icon: "clock", text: context.date.formatted(.dateTime.hour().minute()))
                        Rectangle()
                            .fill(PaperPlanStyle.border.opacity(0.4))
                            .frame(width: 1, height: 14)
                        briefingItem(icon: "hourglass", text: remainingLabel(from: context.date))
                    }
                }
                Rectangle()
                    .fill(PaperPlanStyle.border.opacity(0.4))
                    .frame(width: 1, height: 14)
            }
            briefingItem(
                icon: "sparkles",
                text: "\(priorityCount) \(priorityCount == 1 ? "priority" : "priorities")"
            )
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(PaperPlanStyle.border.opacity(0.4)).frame(height: 1)
        }
    }

    private func briefingItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(PaperPlanStyle.ink)
            Text(text)
                .font(PaperPlanStyle.mono(.caption))
                .foregroundStyle(PaperPlanStyle.muted)
        }
    }

    private func remainingLabel(from now: Date) -> String {
        let calendar = Calendar.current
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let seconds = max(0, Int(startOfNextDay.timeIntervalSince(now)))
        return "\(seconds / 3600)h \(seconds % 3600 / 60)m remaining"
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
                        .foregroundStyle(isCurrent ? PaperPlanStyle.inkOnHighlighter : PaperPlanStyle.ink.opacity(0.85))
                        .padding(.horizontal, isCurrent ? 4 : 0)
                        .background(isCurrent ? PaperPlanStyle.highlighter : Color.clear)
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
                        .foregroundStyle(isCurrent ? PaperPlanStyle.inkOnHighlighter : PaperPlanStyle.ink)
                        .padding(.horizontal, isCurrent ? 4 : 0)
                        .background(isCurrent ? PaperPlanStyle.highlighter : Color.clear)
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
                .foregroundStyle(
                    item.isFlagged
                        ? PaperPlanStyle.inkOnHighlighter
                        : (item.status == .pending ? PaperPlanStyle.ink : PaperPlanStyle.muted)
                )
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
                    .foregroundStyle(
                        item.isFlagged
                            ? PaperPlanStyle.inkOnHighlighter
                            : (item.status == .completed ? PaperPlanStyle.muted : PaperPlanStyle.ink)
                    )
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
