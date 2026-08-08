//
//  DayView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import EventKit
import Flow

private enum AppTab: Hashable { case focus, timeline, search }

struct DayView: View {

    @State private var viewModel = DayViewModel()

    @Query private var allItems: [PlanItem]

    @AppStorage(AppStorageKeys.theme.rawValue)
    private var theme: DFPTheme = .cupertino

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue)
    private var showFlaggedOnly: Bool = false

    @AppStorage(AppStorageKeys.showCompleted.rawValue)
    private var showCompleted: Bool = false

    @AppStorage(AppStorageKeys.showCalendarEvents.rawValue)
    private var showCalendarEvents: Bool = true

    @AppStorage(AppStorageKeys.showReminderItems.rawValue)
    private var showReminderItems: Bool = true

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

    @Environment(\.calendarService)
    private var calendarService: CalendarService?

    @AppStorage(AppStorageKeys.selectedCalendarIDs.rawValue)
    private var selectedCalendarIDsRaw: String = ""

    @Environment(\.remindersService)
    private var remindersService: RemindersService?

    @AppStorage(AppStorageKeys.selectedReminderListIDs.rawValue)
    private var selectedReminderListIDsRaw: String = ""

    @Query(sort: \PlanCategory.name)
    private var allCategories: [PlanCategory]

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var activeTab: AppTab = .focus
    @State private var isShowingCategoriesEdit = false
    @State private var showCategorySelector = false
    @State private var isAddingItem = false
    @State private var itemToEdit: PlanItem? = nil
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var reminderItems: [ReminderItem] = []
    @State private var isAnyTimeDropTargeted = false

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted
    }

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
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    var body: some View {
        TabView(selection: $activeTab) {
            Tab("Focus", systemImage: "airplane", value: AppTab.focus) {
                NavigationStack {
                    dayScrollView
                        .id(viewModel.selectedDate)
                        .transition(dayTransition)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { } label: {
                                    Image(systemName: "gearshape")
                                }
                                .accessibilityLabel("Settings")
                            }

                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Menu {
                                    Toggle(isOn: $showFlaggedOnly) {
                                        Label("Flagged Only", systemImage: "flag.fill")
                                    }
                                    Toggle(isOn: $showCompleted) {
                                        Label("Show Completed", systemImage: "checkmark")
                                    }
                                    Divider()
                                    Toggle(isOn: $showCalendarEvents) {
                                        Label("Calendar Events", systemImage: "calendar")
                                    }
                                    Toggle(isOn: $showReminderItems) {
                                        Label("Reminders", systemImage: "bell")
                                    }
                                } label: {
                                    Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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

                            ToolbarItem(placement: .topBarTrailing) {
                                Button { isAddingItem = true } label: {
                                    Image(systemName: "plus")
                                }
                                .accessibilityLabel("Add Item")
                            }
                        }
                }
            }

            Tab("Timeline", systemImage: "calendar.day.timeline.left", value: AppTab.timeline) {
                TimelineView(
                    onSelectDate: { date in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.navigate(to: date)
                        }
                        activeTab = .focus
                    },
                    onDismiss: { activeTab = .focus }
                )
            }
            
            Tab(value: AppTab.search, role: .search) {
                Text("Search")
                    .navigationTitle("Search")
            }
        }
        .environment(\.editItem) { item in itemToEdit = item }
        .environment(\.importReminderItem) { reminder in importReminder(reminder) }
        .task {
            viewModel.startLiveClock()
            await watchForMidnight()
        }
        .task(id: viewModel.selectedDate) {
            viewModel.clearSummaries()
            viewModel.applyAutoCollapse()
            await fetchCalendarEvents()
            await fetchReminderItems()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                performSpilloverIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task {
                await fetchCalendarEvents()
                await fetchReminderItems()
            }
        }
        .sheet(isPresented: $isShowingCategoriesEdit) {
            CategoriesEditView()
        }
        .sheet(isPresented: $showCategorySelector) {
            categorySelectorSheet
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

    // MARK: Scrolling date header (scrolls with day content)

    private var scrollingDateHeader: some View {
        ZStack {
            VStack(spacing: 2) {
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

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToYesterday() }
                } label: {
                    Image(systemName: "chevron.left").frame(width: 20)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Previous Day")

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToTomorrow() }
                } label: {
                    Image(systemName: "chevron.right").frame(width: 20)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Next Day")
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Progress summary row

    private var progressSummaryRow: some View {
        let items = selectedDateNonCanceledItems
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0
        return HStack(spacing: 12) {
            ProgressRingView(progress: progress, completed: completed, total: total)
            if total == 0 {
                Text("No items planned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if completed == total {
                Text("All done!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            } else {
                Text("\(completed) of \(total) complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: Scrollable day content

    private var dayScrollView: some View {
        let selectedDateItems = itemsForSelectedDate
        let projected = viewModel.projectedRecurringItems(for: viewModel.selectedDate, from: allItems)
        let categoriesActive = categorySelectionService?.hasSelectedCategories ?? false
        let visibleEvents = (showCalendarEvents && !categoriesActive) ? calendarEvents : []
        let rawReminders = (showReminderItems && !categoriesActive) ? reminderItems : []
        let visibleReminders = showCompleted ? rawReminders : rawReminders.filter { !$0.isCompleted }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    scrollingDateHeader

                    ForEach(viewModel.activeSections) { section in
                        let pills = viewModel.sectionPills(section, from: selectedDateItems)
                        let deadlines = viewModel.deadlineRows(section, from: selectedDateItems)
                        let events = viewModel.calendarEventsForSection(section, from: visibleEvents)
                        let reminders = viewModel.reminderItemsForSection(section, from: visibleReminders)
                        let sectionProjected = projected.filter { $0.daySection == section }
                        DaySectionView(
                            section: section,
                            sectionPills: pills,
                            deadlineRows: deadlines,
                            calendarEvents: events,
                            reminderItems: reminders,
                            projectedPills: sectionProjected,
                            summary: viewModel.sectionSummaries[section],
                            isAllClear: isAllClear(for: section),
                            isSummaryLoading: viewModel.loadingSummarySections.contains(section),
                            showNowBar: viewModel.currentSection == section,
                            isCollapsed: viewModel.isCollapsed(section),
                            onToggle: {
                                withAnimation(.spring(duration: 0.25)) {
                                    viewModel.toggleCollapsed(section)
                                }
                                if viewModel.isCollapsed(section) {
                                    viewModel.generateSummaryIfNeeded(
                                        for: section,
                                        items: pills + deadlines,
                                        events: events,
                                        reminders: reminders
                                    )
                                }
                            },
                            onDropItem: { uuidString in
                                handlePillDrop(uuidString: uuidString, targetSection: section)
                            },
                            onReloadSummary: {
                                viewModel.clearSummary(for: section)
                                viewModel.generateSummaryIfNeeded(
                                    for: section,
                                    items: pills + deadlines,
                                    events: events,
                                    reminders: reminders
                                )
                            }
                        )
                        .id(section)
                        .onAppear {
                            if viewModel.isCollapsed(section) {
                                viewModel.generateSummaryIfNeeded(
                                    for: section,
                                    items: pills + deadlines,
                                    events: events,
                                    reminders: reminders
                                )
                            }
                        }
                    }

                    progressSummaryRow
                    missedSection(items: selectedDateItems)
                    anyTimeSection(items: selectedDateItems, visibleReminders: visibleReminders)
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .onAppear {
                if let current = viewModel.currentSection {
                    proxy.scrollTo(current, anchor: .top)
                }
            }
        }
    }

    // MARK: Any time section

    @ViewBuilder
    private func anyTimeSection(items: [PlanItem], visibleReminders: [ReminderItem]) -> some View {
        let anyTimeItems = viewModel.anyTimeItems(from: items)
        let anyTimeReminders = viewModel.anyTimeReminderItems(from: visibleReminders)
        VStack(alignment: .leading, spacing: 10) {
            Text("Open")
                .font(.subheadline.bold())
                .foregroundStyle(isAnyTimeDropTargeted ? Color.accentColor : Color.secondary)
                .padding(.leading, 4)
            if !anyTimeItems.isEmpty {
                HFlow(itemSpacing: 8, rowSpacing: 8) {
                    ForEach(anyTimeItems) { item in
                        ItemPillView(item: item, isMissed: viewModel.isMissed(item))
                            .draggable(item.uuid.uuidString)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !anyTimeReminders.isEmpty {
                VStack(spacing: 0) {
                    ForEach(anyTimeReminders) { item in
                        ReminderItemRow(item: item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(4)
        .contentShape(Rectangle())
        .overlay {
            if isAnyTimeDropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .dropDestination(for: String.self) { dropItems, _ in
            guard let uuidString = dropItems.first else { return false }
            handlePillDrop(uuidString: uuidString, targetSection: nil)
            return true
        } isTargeted: { targeted in
            isAnyTimeDropTargeted = targeted
        }
        .animation(.easeInOut(duration: 0.15), value: isAnyTimeDropTargeted)
    }

    // MARK: Past section (calendar events only — reminders go to Missed)

    @ViewBuilder
    private func pastSectionCard(calendarEvents: [CalendarEvent]) -> some View {
        let pastEvents = viewModel.pastCalendarEvents(from: calendarEvents)
        if !pastEvents.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Past")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(pastEvents) { event in
                        CalendarEventRow(event: event)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    // MARK: Missed section (deadline plan items + past timed reminders)

    @ViewBuilder
    private func missedSection(items: [PlanItem]) -> some View {
        let missedItems = viewModel.missedDeadlineItems(from: items)
        if !missedItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Missed")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(missedItems) { item in
                        DeadlineItemRow(item: item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    // MARK: Import Reminder

    private func importReminder(_ reminder: ReminderItem) {
        let item = PlanItem(
            title: reminder.title,
            notes: reminder.notes ?? "",
            date: Calendar.current.startOfDay(for: viewModel.selectedDate),
            deadline: reminder.dueDate
        )
        item.reminderIdentifier = reminder.id
        modelContext.insert(item)
        try? modelContext.save()
    }

    // MARK: All clear

    /// True when a section has no pending plan items — either empty, or all done/canceled.
    /// Uses unfiltered allItems so it works regardless of the showCompleted toggle.
    private func isAllClear(for section: DaySection) -> Bool {
        let today = viewModel.selectedDate
        let sectionItems = allItems.filter { item in
            Calendar.current.isDate(item.date, inSameDayAs: today)
            && item.daySection == section
        }
        let deadlineItemsInSection = allItems.filter { item in
            guard Calendar.current.isDate(item.date, inSameDayAs: today),
                  item.daySection == nil,
                  let deadline = item.deadline else { return false }
            return DaySection.containing(deadline) == section
        }
        return (sectionItems + deadlineItemsInSection).allSatisfy {
            $0.status == .completed || $0.status == .canceled
        }
    }

    // MARK: Drag to reassign section

    /// Moves a dragged item to `targetSection` (or "Open" if nil), clearing any deadline.
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

    // MARK: Spillover

    /// Moves all pending items from days before today to today.
    private func performSpilloverIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        let toSpill = allItems.filter {
            $0.status == .pending &&
            Calendar.current.startOfDay(for: $0.date) < today
        }
        guard !toSpill.isEmpty else { return }
        for item in toSpill {
            item.date = today
            if item.deadline != nil {
                item.deadline = nil
            }
        }
        try? modelContext.save()
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.goToToday()
        }
    }

    private func watchForMidnight() async {
        while !Task.isCancelled {
            let now = Date.now
            let calendar = Calendar.current
            guard let tomorrow = calendar.date(
                byAdding: .day, value: 1, to: calendar.startOfDay(for: now)
            ) else { break }
            let secondsUntilMidnight = tomorrow.timeIntervalSince(now)
            do {
                try await Task.sleep(for: .seconds(max(1, secondsUntilMidnight + 1)))
            } catch {
                break
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                performSpilloverIfNeeded()
            }
        }
    }

    // MARK: Calendar event fetching

    private func fetchCalendarEvents() async {
        guard let service = calendarService else { return }
        if !service.hasAccess() {
            _ = await service.requestAccess()
        }
        let ids = Set(selectedCalendarIDsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        calendarEvents = await service.events(for: viewModel.selectedDate, calendarIDs: ids)
    }

    // MARK: Reminders fetching

    private func fetchReminderItems() async {
        guard let service = remindersService else { return }
        if !service.hasAccess() {
            _ = await service.requestAccess()
        }
        let ids = Set(selectedReminderListIDsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        reminderItems = await service.reminders(for: viewModel.selectedDate, listIDs: ids)
    }

}

#Preview {
    DayView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
