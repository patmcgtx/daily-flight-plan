//
//  DayView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import EventKit

private enum AppTab: Hashable { case focus, flightDeck, timeline, routines, chat }

struct DayView: View {

    @State private var viewModel = DayViewModel()

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false }) private var allItems: [PlanItem]
    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == true }) private var recurringTemplates: [PlanItem]

    @Environment(\.calendarService)
    private var calendarService: CalendarService?

    @AppStorage(AppStorageKeys.selectedCalendarIDs.rawValue)
    private var selectedCalendarIDsRaw: String = ""

    @Environment(\.remindersService)
    private var remindersService: RemindersService?

    @AppStorage(AppStorageKeys.selectedReminderListIDs.rawValue)
    private var selectedReminderListIDsRaw: String = ""

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var activeTab: AppTab = .focus
    @State private var isShowingSettings = false
    @State private var isShowingImport = false
    @State private var pendingDeleteItems = false
    @State private var pendingDeleteCategories = false
    @State private var isDeletingData = false
    @State private var itemToEdit: PlanItem? = nil
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var reminderItems: [ReminderItem] = []

    var body: some View {
        TabView(selection: $activeTab) {

            Tab("Day", systemImage: "airplane", value: AppTab.flightDeck) {
                FlightPlanView(
                    viewModel: viewModel,
                    calendarEvents: calendarEvents,
                    reminderItems: reminderItems,
                    isDeletingData: isDeletingData,
                    onShowSettings: { isShowingSettings = true },
                    onShowImport: { isShowingImport = true }
                )
            }

            Tab("Log", systemImage: "checklist", value: AppTab.timeline) {
                TimelineView(onSelectDate: { _ in }, onDismiss: {})
            }

            Tab("Routine", systemImage: "infinity", value: AppTab.routines) {
                RoutineView()
            }

            Tab("Comm", systemImage: "apple.intelligence", value: AppTab.chat) {
                ContentUnavailableView(
                    "AI Chat",
                    systemImage: "bubble.left.and.right",
                    description: Text("Plan your day with AI assistance. Coming soon.")
                )
            }
        }
        .onAppear {
            if activeTab == .focus { activeTab = .flightDeck }
        }
        #if os(macOS)
        .overlay(alignment: .topLeading) {
            // Hidden buttons so Cmd+1–4 switch tabs on macOS.
            // opacity(0) keeps keyboard shortcuts active; hidden() would disable them.
            VStack {
                Button("") { activeTab = .flightDeck }.keyboardShortcut("1", modifiers: .command)
                Button("") { activeTab = .timeline }.keyboardShortcut("2", modifiers: .command)
                Button("") { activeTab = .routines }.keyboardShortcut("3", modifiers: .command)
                Button("") { activeTab = .chat }.keyboardShortcut("4", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        #endif
        .environment(\.editItem) { item in itemToEdit = item }
        .environment(\.importReminderItem) { reminder in importReminder(reminder) }
        .task {
            viewModel.startLiveClock()
            await watchForMidnight()
        }
        .task(id: viewModel.selectedDate) {
            viewModel.clearSummaries()
            viewModel.applyAutoCollapse()
            migrateOldRecurringItems()
            if viewModel.isToday {
                materializeRecurringInstances(for: viewModel.selectedDate)
            }
            await fetchCalendarEvents()
            await fetchReminderItems()
        }
        .onChange(of: recurringTemplates.count) { _, _ in
            if viewModel.isToday {
                materializeRecurringInstances(for: viewModel.selectedDate)
            }
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
        .sheet(isPresented: $isShowingSettings, onDismiss: {
            guard pendingDeleteItems || pendingDeleteCategories else { return }
            let deleteItems = pendingDeleteItems
            let deleteCategories = pendingDeleteCategories
            pendingDeleteItems = false
            pendingDeleteCategories = false
            Task { @MainActor in
                isDeletingData = true
                // Let the overlay fully render before touching the store
                try? await Task.sleep(for: .milliseconds(150))
                if deleteItems { ModelContainer.deleteAllItems(in: modelContext) }
                if deleteCategories { ModelContainer.deleteAllCategories(in: modelContext) }
                // Hold the overlay until @Query finishes propagating the deletions
                try? await Task.sleep(for: .seconds(2))
                isDeletingData = false
            }
        }) {
            SettingsView(
                onDeleteItems: { pendingDeleteItems = true },
                onDeleteCategories: { pendingDeleteCategories = true },
                onSeedData: { ModelContainer.seedSampleDataIfNeeded(in: modelContext) }
            )
        }
        .sheet(isPresented: $isShowingImport, onDismiss: {
            if viewModel.isToday { materializeRecurringInstances(for: viewModel.selectedDate) }
        }) {
            MarkdownImportView(selectedDate: viewModel.selectedDate)
        }
        .sheet(item: $itemToEdit, onDismiss: {
            if viewModel.isToday { materializeRecurringInstances(for: viewModel.selectedDate) }
        }) { item in
            ItemForm(item: item)
        }
        .overlay {
            if isDeletingData {
                Rectangle()
                    .fill(.background)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Deleting…")
                            .controlSize(.large)
                    }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDeletingData)
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

    // MARK: Spillover

    /// Moves all pending items from days before today to today.
    private func performSpilloverIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        let toSpill = allItems.filter {
            $0.status == .pending &&
            $0.template == nil &&
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

    // MARK: Recurring item management

    /// Converts any old-style recurring items (pre-template model) to templates.
    private func migrateOldRecurringItems() {
        let oldStyle = allItems.filter { !$0.recurringWeekdays.isEmpty && $0.template == nil }
        guard !oldStyle.isEmpty else { return }
        for item in oldStyle {
            item.isTemplate = true
        }
        try? modelContext.save()
    }

    /// Creates pending per-day instances for each template that matches today's weekday
    /// and has no existing instance for the given date.
    private func materializeRecurringInstances(for date: Date) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let weekdayInt = cal.component(.weekday, from: date)
        let weekdayMap: [Int: Locale.Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        guard let weekday = weekdayMap[weekdayInt] else { return }

        var didInsert = false
        for template in recurringTemplates {
            guard template.recurringWeekdays.contains(weekday) else { continue }
            let instances = template.instances ?? []
            guard !instances.contains(where: { cal.isDate($0.date, inSameDayAs: date) }) else { continue }
            let instanceDeadline: Date? = template.deadline.flatMap { dl in
                cal.date(
                    bySettingHour: cal.component(.hour, from: dl),
                    minute: cal.component(.minute, from: dl),
                    second: 0, of: startOfDay
                )
            }
            let instance = PlanItem(
                title: template.title,
                notes: template.notes,
                isFlagged: template.isFlagged,
                date: startOfDay,
                deadline: instanceDeadline,
                daySection: template.daySection,
                recurringWeekdays: [],
                isTemplate: false
            )
            instance.categories = template.categories
            instance.template = template
            modelContext.insert(instance)
            didInsert = true
        }
        if didInsert {
            try? modelContext.save()
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
