//
//  DayView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import EventKit
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

    @State private var isShowingCategoriesEdit = false
    @State private var isShowingTimeline = false
    @State private var isAddingItem = false
    @State private var itemToEdit: PlanItem? = nil
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var reminderItems: [ReminderItem] = []
    @State private var isAnyTimeDropTargeted = false
    @State private var isCancelZoneTargeted = false
    @State private var isDeferZoneTargeted = false

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
        VStack(spacing: 0) {
            headerView
            Divider()
            dayScrollView
                .id(viewModel.selectedDate)
                .transition(dayTransition)
        }
        .clipped()
        .environment(\.editItem) { item in itemToEdit = item }
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
        .sheet(isPresented: $isShowingTimeline) {
            TimelineView { date in
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.navigate(to: date)
                }
            }
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
        ZStack {
            // Always-centered date display
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

            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToYesterday() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 20)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Previous Day")

                    Button {
                        isShowingTimeline = true
                    } label: {
                        Image(systemName: "calendar.day.timeline.left")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Timeline")
                }

                Spacer()

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

    private var filterRow: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterToggle("Flagged", icon: "flag.fill", isActive: showFlaggedOnly) {
                        showFlaggedOnly.toggle()
                    }
                    filterToggle("Done", icon: "checkmark", isActive: showCompleted) {
                        showCompleted.toggle()
                    }
                    filterToggle("Calendar", icon: "calendar", isActive: showCalendarEvents) {
                        showCalendarEvents.toggle()
                    }
                    filterToggle("Reminders", icon: "bell", isActive: showReminderItems) {
                        showReminderItems.toggle()
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
                .padding(.leading)
                .padding(.trailing, 4)
            }

            Divider().frame(height: 20).padding(.trailing, 8)

            Menu {
                Section("Theme") {
                    ForEach(DFPTheme.allCases) { option in
                        Button { theme = option } label: {
                            Label(option.localizedName, systemImage: option.menuIconName)
                        }
                    }
                }
                Section {
                    Button { } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("More")
            .padding(.trailing)
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
        let projected = viewModel.projectedRecurringItems(for: viewModel.selectedDate, from: allItems)
        let categoriesActive = categorySelectionService?.hasSelectedCategories ?? false
        let visibleEvents = (showCalendarEvents && !categoriesActive) ? calendarEvents : []
        let rawReminders = (showReminderItems && !categoriesActive) ? reminderItems : []
        let visibleReminders = showCompleted ? rawReminders : rawReminders.filter { !$0.isCompleted }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
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
            .safeAreaInset(edge: .bottom) {
                bottomBar
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
    /// Primary trigger: app launch / foreground. Secondary: midnight watcher.
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
                item.deadline = nil  // deadline-based items become "any time" on the new day
            }
        }
        try? modelContext.save()
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.goToToday()
        }
    }

    /// Sleeps until midnight, triggers spillover, then loops for subsequent nights.
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

    // MARK: Bottom bar — Cancel zone | Add button | Defer zone

    private var bottomBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            cancelZone
            Spacer()
            addButton
            Spacer()
            deferZone
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var addButton: some View {
        Button { isAddingItem = true } label: {
            Label("Add Item", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
        }
        .buttonStyle(.glass)
    }

    private var cancelZone: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(isCancelZoneTargeted ? .white : .secondary)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isCancelZoneTargeted ? Color.red : Color.secondary.opacity(0.12))
            )
            .scaleEffect(isCancelZoneTargeted ? 1.25 : 1.0)
            .animation(.spring(duration: 0.25), value: isCancelZoneTargeted)
            .dropDestination(for: String.self) { items, _ in
                guard let uuidString = items.first,
                      let uuid = UUID(uuidString: uuidString),
                      let item = allItems.first(where: { $0.uuid == uuid }) else { return false }
                withAnimation { item.status = .canceled }
                return true
            } isTargeted: { isCancelZoneTargeted = $0 }
            .accessibilityLabel("Cancel Item")
    }

    private var deferZone: some View {
        Image(systemName: "arrow.right.circle.fill")
            .font(.title2)
            .foregroundStyle(isDeferZoneTargeted ? .white : .secondary)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isDeferZoneTargeted ? Color.orange : Color.secondary.opacity(0.12))
            )
            .scaleEffect(isDeferZoneTargeted ? 1.25 : 1.0)
            .animation(.spring(duration: 0.25), value: isDeferZoneTargeted)
            .dropDestination(for: String.self) { items, _ in
                guard let uuidString = items.first,
                      let uuid = UUID(uuidString: uuidString),
                      let item = allItems.first(where: { $0.uuid == uuid }) else { return false }
                let cal = Calendar.current
                let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: item.date))!
                item.date = tomorrow
                if let deadline = item.deadline {
                    item.deadline = cal.date(byAdding: .day, value: 1, to: deadline)
                }
                return true
            } isTargeted: { isDeferZoneTargeted = $0 }
            .accessibilityLabel("Defer to Tomorrow")
    }
}

#Preview {
    DayView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
