//
//  CockpitView.swift
//  DailyFlightPlan
//
// Design-sprint tab: identical functionality and layout to FlightPlanView, restyled with the
// "Cockpit" look (monospaced type, flat black borders, hard offset shadows, highlighter-yellow
// accents) — see Theming/CockpitStyle.swift. Flagged items are called out with a yellow
// highlighter behind the title instead of a flag icon.
import SwiftUI
import SwiftData
import Flow

struct CockpitView: View {

    var viewModel: DayViewModel
    var calendarEvents: [CalendarEvent] = []
    var reminderItems: [ReminderItem] = []
    var isDeletingData: Bool = false
    let onShowSettings: () -> Void
    let onShowImport: () -> Void

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    /// Custom flight names and intentions. Rows are created lazily on first edit.
    @Query private var days: [Day]

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

    @AppStorage(AppStorageKeys.showEmptySegments.rawValue)
    private var showEmptySegments: Bool = true

    @AppStorage(AppStorageKeys.uppercaseText.rawValue)
    private var uppercaseText: Bool = true

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
    @State private var isAllDayExpanded = true
    @State private var isUpNextExpanded = true
    @State private var isPassedExpanded = true
    // Past-day report sections, each collapsible like Up Next.
    @State private var isReportCompletedExpanded = true
    @State private var isReportMissedExpanded = true
    @State private var isReportCanceledExpanded = true
    @State private var isConfirmingCancelAllPassed = false

    @State private var searchText: String = ""
    @State private var isShowingSearch = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isShowingExport = false
    @FocusState private var isDestinationFocused: Bool

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (categorySelectionService?.hasSelectedCategories ?? false)
    }

    var body: some View {
        NavigationStack {
            dayContent(for: viewModel.selectedDate)
                .background {
                    CockpitStyle.background.ignoresSafeArea()
                }
                .safeAreaInset(edge: .top) {
                    if isShowingSearch {
                        InlineSearchField(text: $searchText, isFocused: $isSearchFieldFocused)
                    }
                }
                .inlineNavigationTitle()
                .toolbar {
                    // One compact leading control (rather than two buttons) frees toolbar width
                    // so the trailing items, including the View menu, aren't pushed into the
                    // system overflow menu.
                    ToolbarItem(placement: .leadingBar) {
                        Menu {
                            Button { onShowSettings() } label: {
                                Label("Developer", systemImage: "hammer")
                            }
                            Button { onShowImport() } label: {
                                Label("Import", systemImage: "square.and.arrow.down")
                            }
                            Button { isShowingExport = true } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("More")
                    }

                    ToolbarItemGroup(placement: .trailingBar) {
                        SearchToggleButton(
                            isShowingSearch: $isShowingSearch, searchText: $searchText,
                            isFocused: $isSearchFieldFocused
                        )

                        CockpitViewMenu(isPastDay: viewModel.isPastDay)

                        CategoriesToolbarButton()
                    }
                }
                #if os(iOS)
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar, .tabBar)
                #endif
        }
        .tint(CockpitStyle.ink)
        .overlay(alignment: .bottomTrailing) {
            // A past day is a read-only report, so nothing can be added to it.
            if !viewModel.isPastDay {
                Button { isAddingItem = true } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .buttonStyle(.glass)
                .tint(CockpitStyle.highlighter)
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .accessibilityLabel("Add Item")
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
        .sheet(isPresented: $isShowingExport) {
            MarkdownExportView(
                title: "Export Day Plan",
                markdown: DayPlanMarkdownExporter.export(
                    items: exportItems(for: viewModel.selectedDate),
                    date: viewModel.selectedDate,
                    flightNumber: displayedFlightNumber(for: viewModel.selectedDate),
                    intention: existingDay(for: viewModel.selectedDate)?.intention ?? ""
                )
            )
        }
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
        // Timed entries that aren't over live in Up Next, and anything still open once its time
        // or segment ended in Passed. The sections hold the rest: untimed items, plus ended
        // calendar events and completed items.
        let agenda = viewModel.agenda(items: items, events: visibleEvents, reminders: visibleReminders)
        let rawSectionItems = viewModel.sectionItems(from: raw)

        ScrollView {
            VStack(spacing: 16) {
                dayLabel(for: date)

                flightStatusCard(raw, date: date)

                briefingRow(raw, date: date)

                if viewModel.isPastDay {
                    pastDayReportView(
                        date: date,
                        report: viewModel.pastDayReport(items: reportItems(for: date))
                    )
                } else {
                    if !agenda.allDay.isEmpty {
                        allDayCard(agenda.allDay)
                    }

                    if !agenda.upcoming.isEmpty {
                        upNextCard(agenda.upcoming)
                    }

                    ForEach(DaySection.allCases) { section in
                        // Passed sits right before the current segment, after the ended ones.
                        if section == viewModel.currentSection && !agenda.passed.isEmpty {
                            passedCard(agenda.passed)
                        }
                        // Empty segments can be hidden from the View menu. Past segments tend to go
                        // empty on their own, since their open items move to Passed. The current
                        // segment always stays: it carries the NOW marker and the Add item button.
                        if showEmptySegments || section == viewModel.currentSection
                            || viewModel.hasContent(section, in: agenda) {
                            sectionCard(
                                section, date: date, items: agenda.sectionItems, raw: rawSectionItems
                            )
                        }
                    }

                    let openItems = viewModel.anyTimeItems(from: agenda.sectionItems)
                    let anyTimeReminders = viewModel.anyTimeReminderItems(from: visibleReminders)
                    if !openItems.isEmpty || !anyTimeReminders.isEmpty {
                        openCard(openItems, date: date, anyTimeReminders: anyTimeReminders)
                    }
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            CockpitStyle.background.ignoresSafeArea()
        }
    }

    private func dayLabel(for date: Date) -> some View {
        HStack(spacing: 12) {
            dayArrowButton(systemImage: "chevron.left") {
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToYesterday() }
            }
            DatePickerButton(
                selectedDate: Binding(
                    get: { viewModel.selectedDate },
                    set: { newDate in
                        withAnimation(.easeInOut(duration: 0.3)) { viewModel.navigate(to: newDate) }
                    }
                ),
                isToday: viewModel.isToday,
                onSelectToday: {
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.goToToday() }
                }
            ) {
                dayLabelText(for: date)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Choose Date")
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
                .foregroundStyle(CockpitStyle.ink)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .background(CockpitStyle.surface)
        .overlay(Rectangle().stroke(CockpitStyle.border, lineWidth: 1.5))
        .background {
            Rectangle().fill(CockpitStyle.shadow).offset(x: 2, y: 3)
        }
    }

    private func dayLabelText(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isTomorrow = Calendar.current.isDateInTomorrow(date)
        let isYesterday = Calendar.current.isDateInYesterday(date)
        return VStack(spacing: 4) {
            // Date sits above the weekday, alongside the Today/Tomorrow/Yesterday label if any
            HStack(spacing: 6) {
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(CockpitStyle.mono(.subheadline))
                    .cockpitUppercase()
                    .foregroundStyle(CockpitStyle.muted)
                if isToday {
                    Text("Today")
                        .font(CockpitStyle.mono(.caption, weight: .bold))
                        .cockpitUppercase()
                        .foregroundStyle(CockpitStyle.inkOnHighlighter)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CockpitStyle.highlighter)
                } else if isTomorrow || isYesterday {
                    Text(isTomorrow ? "Tomorrow" : "Yesterday")
                        .font(CockpitStyle.mono(.caption, weight: .bold))
                        .cockpitUppercase()
                        .foregroundStyle(CockpitStyle.muted)
                }
            }
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(CockpitStyle.mono(.largeTitle, weight: .bold))
                .cockpitUppercase()
                .foregroundStyle(CockpitStyle.ink)
        }
    }

    // MARK: - Day details (flight name + intention)

    /// The stored `Day` for `date`, from the `@Query` — fine for display, but may lag a render
    /// behind a just-inserted row, so writes go through `dayForEditing(_:)` instead.
    private func existingDay(for date: Date) -> Day? {
        let key = Day.normalized(date)
        return days.filter { Day.normalized($0.date) == key }.max { $0.modifiedAt < $1.modifiedAt }
    }

    /// The `Day` to write to for `date`, created on first use. Fetches from the context rather
    /// than `days` so rapid consecutive edits can't insert a duplicate row.
    private func dayForEditing(_ date: Date) -> Day {
        if let existing = fetchedDay(for: date) { return existing }
        let day = Day(date: date)
        modelContext.insert(day)
        return day
    }

    /// The newest stored `Day` for `date`, fetched straight from the context.
    private func fetchedDay(for date: Date) -> Day? {
        let start = Day.normalized(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func displayedFlightNumber(for date: Date) -> String {
        existingDay(for: date)?.displayFlightNumber ?? Day.defaultFlightNumber(for: date)
    }

    /// Stores `text` as the flight name for `date`. Blank text, or text equal to the default
    /// number, is stored as "" so the name keeps tracking the default; a row left with nothing
    /// customized is deleted rather than synced as an empty record.
    private func commitFlightName(_ text: String, for date: Date) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDefault = trimmed.isEmpty || trimmed == Day.defaultFlightNumber(for: date)
        guard !isDefault else {
            guard let day = existingDay(for: date) ?? fetchedDay(for: date) else { return }
            day.setFlightName("")
            if day.isBlank { modelContext.delete(day) }
            return
        }
        dayForEditing(date).setFlightName(text)
    }

    /// The flight name caption, editable inline. It shows the default "DFP YYYYMMDD" number as
    /// real text, so the user can tweak it (e.g. append a suffix) rather than retype the date.
    private func flightNameField(for date: Date) -> some View {
        FlightNameField(
            caption: viewModel.isPastDay ? "Flight Report" : "Flight",
            displayed: displayedFlightNumber(for: date),
            defaultNumber: Day.defaultFlightNumber(for: date),
            commit: { commitFlightName($0, for: date) }
        )
        // A fresh field (and draft) per day.
        .id(Day.normalized(date))
    }

    /// "DESTINATION" label with a short, multi-line-capable note on what the day is for, shown
    /// in the Flight Status card beside the progress box.
    private func destinationField(for date: Date) -> some View {
        let intention = Binding(
            get: { existingDay(for: date)?.intention ?? "" },
            set: { text in
                // A vertical-axis field inserts a newline on Return; treat Return as "Done"
                // instead — dismiss the keyboard and keep the text to a single paragraph.
                if text.contains("\n") {
                    isDestinationFocused = false
                    dayForEditing(date).setIntention(
                        text.replacingOccurrences(of: "\n", with: "")
                    )
                } else {
                    dayForEditing(date).setIntention(text)
                }
            }
        )
        return VStack(alignment: .leading, spacing: 2) {
            // A past day is a static report, so its note goes without the label.
            if !viewModel.isPastDay {
                Text("Destination")
                    .font(CockpitStyle.mono(.caption2, weight: .bold))
                    .cockpitUppercase()
                    .foregroundStyle(CockpitStyle.muted)
            }
            // The placeholder is a separate Text rather than the field's `prompt`, which
            // truncates to one line instead of wrapping.
            ZStack(alignment: .topLeading) {
                if intention.wrappedValue.isEmpty {
                    Text("What is this \(date.formatted(.dateTime.weekday(.wide))) for?")
                        .font(CockpitStyle.mono(.caption2))
                        .foregroundStyle(CockpitStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextField("", text: intention, axis: .vertical)
                    .font(CockpitStyle.mono(.caption2))
                    .foregroundStyle(CockpitStyle.ink)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .fixedSize(horizontal: false, vertical: true)
                    .focused($isDestinationFocused)
                    .submitLabel(.done)
                    .onSubmit { isDestinationFocused = false }
                    .accessibilityLabel("Day destination")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func flightStatusCard(_ items: [PlanItem], date: Date) -> some View {
        let completed = items.filter { $0.status == .completed }.count
        let total = items.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                paperProgressBox(completed: completed, total: total, pct: pct)
                VStack(alignment: .leading, spacing: 4) {
                    flightNameField(for: date)
                    destinationField(for: date)
                    if !viewModel.isPastDay, let nextUp = nextUpTime(items, referenceDate: date) {
                        Text("Next up at \(nextUp)")
                            .font(CockpitStyle.mono(.caption))
                            .foregroundStyle(CockpitStyle.muted)
                    }
                }
                Spacer()
            }
            .padding(14)

            if !viewModel.isPastDay {
                Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)

                routeIntentionsLine()
                    .padding(14)
            }
        }
        .background(CockpitStyle.surface)
        .overlay(Rectangle().stroke(CockpitStyle.border, lineWidth: 1.5))
        .background {
            Rectangle().fill(CockpitStyle.shadow).offset(x: 3, y: 4)
        }
    }

    /// "06 ROUTE" from the mockup's flight-plan masthead, repurposed as a quick
    /// glance at the day's sections — the current section (if viewing today) bolds; the rest
    /// stay plain.
    private func routeIntentionsLine() -> some View {
        let sections = DaySection.allCases
        let label = Text("ROUTE:  ")
            .font(CockpitStyle.mono(.caption2, weight: .bold))
            .foregroundColor(CockpitStyle.muted)
        let line = sections.enumerated().reduce(label) { partial, entry in
            let (index, section) = entry
            let isCurrent = section == viewModel.currentSection

            let segment = Text(uppercaseText ? section.displayName.uppercased() : section.displayName)
                .font(CockpitStyle.mono(.caption2, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? CockpitStyle.ink : CockpitStyle.muted)

            guard index > 0 else { return partial + segment }
            let arrow = Text(" \u{2192} ")
                .font(CockpitStyle.mono(.caption2))
                .foregroundColor(CockpitStyle.muted)
            return partial + arrow + segment
        }

        return line
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paperProgressBox(completed: Int, total: Int, pct: Double) -> some View {
        let size: CGFloat = 60
        return ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(CockpitStyle.ink).frame(width: size * pct)
                Rectangle().fill(CockpitStyle.border.opacity(0.25)).frame(width: size * (1 - pct))
            }
            .frame(width: size, height: size)
            Rectangle().fill(CockpitStyle.surface).frame(width: size - 10, height: size - 10)
            Rectangle().stroke(CockpitStyle.border, lineWidth: 1).frame(width: size, height: size)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(completed)")
                    .font(CockpitStyle.mono(.title3, weight: .bold))
                    .foregroundStyle(CockpitStyle.ink)
                Text("/\(total)")
                    .font(CockpitStyle.mono(.caption2))
                    .foregroundStyle(CockpitStyle.muted)
            }
        }
        .frame(width: size, height: size)
    }

    /// The earliest upcoming deadline among this date's pending items — preferring ones still
    /// ahead of the live clock when viewing today, falling back to the day's earliest deadline
    /// otherwise (e.g. a past day, or a today whose remaining deadlines have all slipped by).
    private func nextUpTime(_ items: [PlanItem], referenceDate: Date) -> String? {
        viewModel.nextUpcomingDeadline(from: items, referenceDate: referenceDate)?
            .formatted(.dateTime.hour().minute())
    }

    /// A thin rule-bordered strip echoing the mockup's weather/time/priorities "briefing" row —
    /// weather is skipped (no data source for it) in favor of the current time of day. Both the
    /// clock and the countdown tick every second via `TimelineView` rather than the shared
    /// `DayViewModel` clock, which only updates per-minute for the rest of the app.
    private func briefingRow(_ items: [PlanItem], date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let priorityCount = viewModel.outstandingFlaggedCount(from: items)

        return HStack(spacing: 14) {
            Spacer()
            if isToday {
                SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 14) {
                        briefingItem(icon: "clock", text: context.date.formatted(.dateTime.hour().minute()))
                        Rectangle()
                            .fill(CockpitStyle.border.opacity(0.4))
                            .frame(width: 1, height: 14)
                        briefingItem(icon: "hourglass", text: remainingLabel(from: context.date))
                    }
                }
                Rectangle()
                    .fill(CockpitStyle.border.opacity(0.4))
                    .frame(width: 1, height: 14)
            } else {
                // Past and future days have no live clock/countdown. A past day recaps how it
                // went; a future one gets a blurb.
                briefingItem(
                    icon: nil,
                    text: viewModel.isPastDay
                        ? pastDayRecap(for: date)
                        : "Future you"
                )
                Rectangle()
                    .fill(CockpitStyle.border.opacity(0.4))
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
            Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
        }
    }

    private func briefingItem(icon: String?, text: String) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(CockpitStyle.ink)
            }
            Text(text)
                .font(CockpitStyle.mono(.caption))
                .foregroundStyle(CockpitStyle.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    // MARK: - Markdown export

    /// Every item on `date`, including canceled ones — completion status (pending/completed/
    /// canceled) is itself part of what `DayPlanMarkdownExporter` renders, so this intentionally
    /// doesn't apply the search/flag/completed/category filters `activeItems(for:)` uses for
    /// on-screen display.
    private func exportItems(for date: Date) -> [PlanItem] {
        allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
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
            let agenda = viewModel.agenda(
                items: activeItems(for: viewModel.selectedDate),
                events: visibleEvents, reminders: visibleReminders
            )
            expandedSections = Set(DaySection.allCases.filter { viewModel.hasContent($0, in: agenda) })
        } else {
            initializeExpandedSections()
        }
    }

    /// Returns false only when the drop is refused (an open item onto an already-ended segment),
    /// so the drag springs back instead of the item reappearing in Passed.
    private func handlePillDrop(uuidString: String, targetSection: DaySection?) -> Bool {
        guard let uuid = UUID(uuidString: uuidString),
              let item = allItems.first(where: { $0.uuid == uuid }) else { return true }
        guard viewModel.canMove(item, to: targetSection) else { return false }
        guard item.daySection != targetSection || item.deadline != nil else { return true }
        withAnimation(.spring(duration: 0.3)) {
            item.daySection = targetSection
            item.deadline = nil
        }
        try? modelContext.save()
        return true
    }

    // MARK: - Section card

    private func sectionCard(
        _ section: DaySection,
        date: Date,
        items: [PlanItem],
        raw: [PlanItem]
    ) -> some View {
        let pills = viewModel.sectionPills(section, from: items)
        let regularPills = pills.filter { !$0.isRecurring }
        let routinePills = pills.filter { $0.isRecurring }
        let deadlines = viewModel.deadlineRows(section, from: items)
        let allSectionItems = pills + deadlines
        let hasContent = !allSectionItems.isEmpty
        let contentSignature = viewModel.contentSignature(items: allSectionItems, events: [], reminders: [])
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

                Rectangle().fill(CockpitStyle.border).frame(height: 1)

                Button {
                    addingToSection = section
                    addingItemForDate = date
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(CockpitStyle.mono(.caption, weight: .semibold))
                        .cockpitUppercase()
                        .foregroundStyle(CockpitStyle.ink)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                }
                .buttonStyle(.plain)

                if !hasContent {
                    Text("Nothing scheduled")
                        .font(CockpitStyle.mono(.subheadline))
                        .foregroundStyle(CockpitStyle.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if !regularPills.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "calendar.day.timeline.left")
                                    .font(.caption)
                                    .foregroundStyle(CockpitStyle.muted)
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
                                Image(systemName: "wrench")
                                    .font(.caption)
                                    .foregroundStyle(CockpitStyle.muted)
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
                            Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
                        }
                        ForEach(deadlines) { item in
                            cardDeadlineRow(item)
                            if item.id != deadlines.last?.id {
                                Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1).padding(.leading, 54)
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
                        hasOverdue: hasOverdue,
                        hasFlagged: rawAll.contains { $0.isFlagged && $0.status == .pending }
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .background { Rectangle().fill(CockpitStyle.surface) }
        .clipShape(Rectangle())
        .overlay {
            let isDropTargeted = dropTargetedSection == section
            Rectangle()
                .stroke(
                    isDropTargeted ? CockpitStyle.highlighter : CockpitStyle.border,
                    lineWidth: isDropTargeted ? 3 : isCurrent ? 2.5 : 1.5
                )
        }
        .background {
            Rectangle().fill(CockpitStyle.shadow).offset(x: 3, y: 4)
        }
        .dropDestination(for: String.self) { dropItems, _ in
            guard let uuidString = dropItems.first else { return false }
            return handlePillDrop(uuidString: uuidString, targetSection: section)
        } isTargeted: { targeted in
            dropTargetedSection = targeted ? section : nil
        }
        .animation(.easeInOut(duration: 0.15), value: dropTargetedSection == section)
        .onAppear {
            guard isSelectedDate else { return }
            if hasContent {
                viewModel.refreshSummaryIfNeeded(for: section, items: allSectionItems, events: [], reminders: [])
            }
        }
        .onChange(of: contentSignature) { _, _ in
            guard isSelectedDate else { return }
            if hasContent {
                viewModel.refreshSummaryIfNeeded(for: section, items: allSectionItems, events: [], reminders: [])
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

            Rectangle().fill(CockpitStyle.border).frame(height: 1)

            Button {
                addingItemForDate = date
                isAddingItem = true
            } label: {
                Label("Add item", systemImage: "plus")
                    .font(CockpitStyle.mono(.caption, weight: .semibold))
                    .cockpitUppercase()
                    .foregroundStyle(CockpitStyle.ink)
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
                if !items.isEmpty { Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1) }
                VStack(spacing: 0) {
                    ForEach(anyTimeReminders) { reminder in
                        ReminderItemRow(item: reminder)
                    }
                }
            }
        }
        .padding(.bottom, 4)
        .background(CockpitStyle.surface)
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(isOpenDropTargeted ? CockpitStyle.highlighter : CockpitStyle.border,
                        lineWidth: isOpenDropTargeted ? 3 : 1.5)
        }
        .background {
            Rectangle().fill(CockpitStyle.shadow).offset(x: 3, y: 4)
        }
        .dropDestination(for: String.self) { dropItems, _ in
            guard let uuidString = dropItems.first else { return false }
            return handlePillDrop(uuidString: uuidString, targetSection: nil)
        } isTargeted: { targeted in
            isOpenDropTargeted = targeted
        }
        .animation(.easeInOut(duration: 0.15), value: isOpenDropTargeted)
    }

    // MARK: - Past-day report

    /// "3 done · 2 missed", counting every item on the day regardless of the on-screen filters.
    private func pastDayRecap(for date: Date) -> String {
        // Like the other render-time reads, skip the query while Delete All Items runs, when
        // its models may already be invalidated.
        guard !isDeletingData else { return "0 done · 0 missed" }
        let all = exportItems(for: date)
        let done = all.filter { $0.status == .completed }.count
        let missed = all.filter { $0.status == .pending }.count
        return "\(done) done · \(missed) missed"
    }

    /// Every item on `date`, canceled included. The Completed filter is forced on, since a report
    /// is about what got done, but the Flagged Only, Maintenance, search and category filters
    /// still narrow it.
    private func reportItems(for date: Date) -> [PlanItem] {
        guard !isDeletingData else { return [] }
        let matching = exportItems(for: date)
            .matchingDayStatusFilters(
                showFlaggedOnly: showFlaggedOnly, showCompleted: true, showRecurring: showRecurring
            )
            .matchingSearchText(searchText)
        return categorySelectionService?.filterItems(matching) ?? matching
    }

    private enum ReportTone {
        case standard, missed, canceled
    }

    /// The report for a day that's over, in the same on-the-page style as Up Next and All Day.
    /// Read-only: rows can't be completed, edited, or dragged.
    @ViewBuilder
    private func pastDayReportView(date: Date, report: PastDayReport) -> some View {
        if report.isEmpty {
            // An empty report is either an empty day or a day whose items the filters (search,
            // categories, Flagged Only, Maintenance) hide, so say which. While Delete All Items
            // runs, skip the query as elsewhere and treat the day as empty.
            let isDayEmpty = isDeletingData || exportItems(for: date).isEmpty
            Text(isDayEmpty ? "Nothing was planned for this day." : "No items match the current filters.")
                .font(CockpitStyle.mono(.caption))
                .foregroundStyle(CockpitStyle.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }

        if !report.completed.isEmpty {
            reportSection(
                "Completed", count: report.completed.count, isExpanded: $isReportCompletedExpanded
            ) {
                ForEach(report.completed) { item in
                    Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
                    reportItemRow(item, tone: .standard)
                }
            }
        }

        if !report.missed.isEmpty {
            reportSection(
                "Missed", count: report.missed.count, isExpanded: $isReportMissedExpanded,
                tone: .missed
            ) {
                ForEach(report.missed) { item in
                    Rectangle().fill(Color.orange.opacity(0.6)).frame(height: 1)
                    reportItemRow(item, tone: .missed)
                }
            }
        }

        if !report.canceled.isEmpty {
            reportSection(
                "Canceled", count: report.canceled.count, isExpanded: $isReportCanceledExpanded,
                tone: .canceled
            ) {
                ForEach(report.canceled) { item in
                    Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
                    reportItemRow(item, tone: .canceled)
                }
            }
        }
    }

    /// A collapsible report section with the Up Next header look: big uppercase title, a count
    /// count while collapsed, and a chevron. Missed borrows Passed's orange italic; Canceled is
    /// muted.
    private func reportSection<Rows: View>(
        _ title: String, count: Int, isExpanded: Binding<Bool>, tone: ReportTone = .standard,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        let titleColor: Color = switch tone {
        case .standard: CockpitStyle.ink.opacity(0.85)
        case .missed: .orange
        case .canceled: CockpitStyle.muted
        }
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 8) {
                    if tone == .missed {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.orange)
                    }
                    Text(title)
                        .font(CockpitStyle.mono(.title2, weight: .bold))
                        .italic(tone == .missed)
                        .cockpitUppercase()
                        .foregroundStyle(titleColor)
                    Spacer()
                    // Plain, not highlighted: nothing here is pending any more.
                    if !isExpanded.wrappedValue {
                        Text("\(count)")
                            .font(CockpitStyle.mono(.caption, weight: .bold))
                            .foregroundStyle(CockpitStyle.muted)
                    }
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(CockpitStyle.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(count) \(count == 1 ? "item" : "items")")
            .accessibilityHint(isExpanded.wrappedValue ? "Collapse" : "Expand")

            if isExpanded.wrappedValue {
                rows()
            }
        }
    }

    /// A read-only plan item row: a status glyph in place of `cardDeadlineRow`'s toggle button,
    /// and no context menu.
    private func reportItemRow(_ item: PlanItem, tone: ReportTone) -> some View {
        let glyph: String? = switch item.status {
        case .completed: "checkmark"
        case .canceled: "xmark"
        case .pending: nil
        }
        let glyphColor: Color = switch item.status {
        case .completed: CockpitStyle.routeBlue
        case .canceled: CockpitStyle.muted
        case .pending: .orange
        }
        let statusLabel: String = switch item.status {
        case .completed: "Completed"
        case .canceled: "Canceled"
        case .pending: "Missed"
        }
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(glyphColor.opacity(item.status == .pending ? 0.6 : 1), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                if let glyph {
                    Image(systemName: glyph)
                        .font(.caption.bold())
                        .foregroundStyle(glyphColor)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(CockpitStyle.mono(.body, weight: .semibold))
                    .cockpitUppercase()
                    .strikethrough(item.status != .pending)
                    .foregroundStyle(
                        item.isFlagged
                            ? CockpitStyle.inkOnHighlighter
                            : (item.status == .pending ? CockpitStyle.ink : CockpitStyle.muted)
                    )
                    .padding(.horizontal, item.isFlagged ? 3 : 0)
                    .background(item.isFlagged ? CockpitStyle.highlighter.opacity(0.8) : Color.clear)
                if let dl = item.deadline {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2)
                        Text(dl, format: .dateTime.hour().minute())
                            .font(CockpitStyle.mono(.caption2))
                    }
                    .foregroundStyle(CockpitStyle.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusLabel)
    }

    // MARK: - Up Next / Past

    /// The day's all-day calendar events, above Up Next and styled like it (drawn on the page,
    /// collapsible by tapping the header). The count stays visible while collapsed.
    private func allDayCard(_ events: [CalendarEvent]) -> some View {
        // Like Up Next / Scheduled, the title reads "Today" only when viewing today.
        let title = viewModel.isToday ? "Today" : "All Day"
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { isAllDayExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(CockpitStyle.mono(.title2, weight: .bold))
                        .cockpitUppercase()
                        .foregroundStyle(CockpitStyle.ink.opacity(0.85))
                    Spacer()
                    if !isAllDayExpanded {
                        Text("\(events.count)")
                            .font(CockpitStyle.mono(.caption, weight: .bold))
                            .foregroundStyle(CockpitStyle.inkOnHighlighter)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CockpitStyle.highlighter)
                    }
                    Image(systemName: isAllDayExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(CockpitStyle.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(events.count) \(events.count == 1 ? "event" : "events")")
            .accessibilityHint(isAllDayExpanded ? "Collapse" : "Expand")

            if isAllDayExpanded {
                ForEach(events) { event in
                    Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
                    CalendarEventRow(event: event)
                }
            }
        }
    }

    /// Every timed commitment for the day in one chronological list. On today the soonest
    /// entry is flagged with a highlighter bar and a countdown; other days just list the day's
    /// schedule. Drawn straight on the page, with no card, border or shadow, so it doesn't read
    /// as another day segment.
    private func upNextCard(_ entries: [DayEntry]) -> some View {
        let isToday = viewModel.isToday
        return VStack(alignment: .leading, spacing: 0) {
            // Tap the header to collapse the list. The countdown chip stays visible while
            // collapsed, so the next commitment is still one glance away.
            Button {
                withAnimation(.spring(duration: 0.3)) { isUpNextExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(isToday ? "Up Next" : "Scheduled")
                        .font(CockpitStyle.mono(.title2, weight: .bold))
                        .cockpitUppercase()
                        .foregroundStyle(CockpitStyle.ink.opacity(0.85))
                    Spacer()
                    if isToday, let next = entries.first {
                        Text(viewModel.countdownLabel(for: next))
                            .font(CockpitStyle.mono(.caption, weight: .bold))
                            .cockpitUppercase()
                            .foregroundStyle(CockpitStyle.inkOnHighlighter)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CockpitStyle.highlighter)
                    }
                    Image(systemName: isUpNextExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(CockpitStyle.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isUpNextExpanded ? "Collapse" : "Expand")

            if isUpNextExpanded {
                ForEach(entries) { entry in
                    Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
                    agendaRow(entry)
                        .overlay(alignment: .leading) {
                            if isToday && entry.id == entries.first?.id {
                                Rectangle().fill(CockpitStyle.highlighter).frame(width: 4)
                            }
                        }
                }
            }
        }
    }

    /// Expanded by default, shown right before the current segment: open timed items and
    /// reminders whose time has gone, plus open items (routines included) left behind once their
    /// day section ended. Calendar events never land here. Orange and italic, and drawn straight
    /// on the page with no card or border, so it stands apart from the live segments.
    private func passedCard(_ entries: [DayEntry]) -> some View {
        let planItems = entries.compactMap { entry -> PlanItem? in
            if case .planItem(let item) = entry { return item }
            return nil
        }
        let contentSignature = viewModel.passedSummarySignature(entries: entries)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { isPassedExpanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.orange)
                        Text("Passed")
                            .font(CockpitStyle.mono(.headline, weight: .bold))
                            .italic()
                            .cockpitUppercase()
                            .foregroundStyle(Color.orange)
                        Spacer()
                        Image(systemName: isPassedExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(CockpitStyle.muted)
                    }
                    // Like a collapsed segment, the one-line AI summary stands in for the list.
                    if !isPassedExpanded {
                        if let summary = viewModel.passedSummary {
                            Text(summary)
                                .font(CockpitStyle.mono(.caption))
                                .italic()
                                .foregroundStyle(CockpitStyle.muted)
                                .lineLimit(2)
                        } else if viewModel.isLoadingPassedSummary {
                            loadingDotsView
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Passed, \(entries.count) \(entries.count == 1 ? "item" : "items")")
            .accessibilityHint(isPassedExpanded ? "Collapse" : "Expand")

            if isPassedExpanded {
                if !planItems.isEmpty {
                    Rectangle().fill(Color.orange.opacity(0.6)).frame(height: 1)
                    HFlow(spacing: 10) {
                        passedActionButton("Move all to now", systemImage: "arrow.uturn.forward") {
                            moveToNow(planItems)
                        }
                        passedActionButton("Cancel all", systemImage: "xmark.circle") {
                            isConfirmingCancelAllPassed = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                // Oldest first across both row styles: runs of plan items share a flow layout,
                // and each reminder is its own row.
                ForEach(viewModel.passedRuns(from: entries)) { run in
                    Rectangle().fill(CockpitStyle.border.opacity(0.4)).frame(height: 1)
                    switch run {
                    case .pills(let items):
                        // Same flow layout and drag-and-drop as the segments, so a passed item
                        // can be dropped straight onto the segment it should move to.
                        HFlow(spacing: 8) {
                            ForEach(items) { item in
                                paperPill(item, isPassed: true)
                                    .draggable(item.uuid.uuidString)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    case .reminder(let reminder):
                        // Reminders are read-only, so they stay as rows rather than pills.
                        ReminderItemRow(item: reminder)
                    }
                }
            }
        }
        .confirmationDialog(
            "Cancel \(planItems.count) passed \(planItems.count == 1 ? "item" : "items")?",
            isPresented: $isConfirmingCancelAllPassed,
            titleVisibility: .visible
        ) {
            Button("Cancel \(planItems.count) \(planItems.count == 1 ? "Item" : "Items")", role: .destructive) {
                cancel(planItems)
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Reminders in this list aren't affected.")
        }
        .onAppear {
            viewModel.refreshPassedSummaryIfNeeded(entries: entries)
        }
        .onChange(of: contentSignature) { _, _ in
            viewModel.refreshPassedSummaryIfNeeded(entries: entries)
        }
    }

    private func passedActionButton(
        _ title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(CockpitStyle.mono(.caption, weight: .bold))
                .cockpitUppercase()
                .foregroundStyle(CockpitStyle.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(Rectangle().stroke(CockpitStyle.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// One row of Up Next, in each source's existing row style.
    @ViewBuilder
    private func agendaRow(_ entry: DayEntry) -> some View {
        switch entry {
        case .planItem(let item):
            cardDeadlineRow(item)
        case .calendarEvent(let event):
            CalendarEventRow(event: event)
        case .reminder(let reminder):
            ReminderItemRow(item: reminder)
        }
    }

    /// Gives passed items back to the current section (untimed) so they're live again.
    private func moveToNow(_ items: [PlanItem]) {
        withAnimation(.spring(duration: 0.3)) {
            for item in items {
                item.daySection = viewModel.currentSection
                item.deadline = nil
            }
        }
        try? modelContext.save()
    }

    private func cancel(_ items: [PlanItem]) {
        withAnimation(.spring(duration: 0.3)) {
            for item in items { item.status = .canceled }
        }
        try? modelContext.save()
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
                        .font(CockpitStyle.mono(.title2, weight: .bold))
                        .cockpitUppercase()
                        .foregroundStyle(isCurrent ? CockpitStyle.inkOnHighlighter : CockpitStyle.ink.opacity(0.85))
                        .padding(.horizontal, isCurrent ? 4 : 0)
                        .background(isCurrent ? CockpitStyle.highlighter : Color.clear)
                    Spacer()
                }

                HStack(spacing: 5) {
                    if isCurrent {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("NOW  ·")
                            .font(CockpitStyle.mono(.caption, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    Text(subtitle)
                        .font(CockpitStyle.mono(.caption))
                        .cockpitUppercase()
                        .foregroundStyle(CockpitStyle.muted)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(CockpitStyle.border.opacity(0.25), lineWidth: 6)
                if total > 0 {
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(
                            allDone ? Color.green : CockpitStyle.ink,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.4), value: completed)
                }
                Text(hasOverdue ? "! \(completed)/\(total)" : "\(completed)/\(total)")
                    .font(CockpitStyle.mono(.caption2, weight: .bold))
                    .foregroundStyle(allDone && total > 0 ? Color.green : hasOverdue ? Color.orange : CockpitStyle.muted)
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
        hasOverdue: Bool = false,
        hasFlagged: Bool = false
    ) -> some View {
        let summary = viewModel.sectionSummaries[section]
        let isLoading = viewModel.loadingSummarySections.contains(section)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(section.displayName)
                        .font(CockpitStyle.mono(.headline, weight: .bold))
                        .cockpitUppercase()
                        .foregroundStyle(isCurrent ? CockpitStyle.inkOnHighlighter : CockpitStyle.ink)
                        .padding(.horizontal, isCurrent ? 4 : 0)
                        .background(isCurrent ? CockpitStyle.highlighter : Color.clear)
                    Text("·")
                        .font(CockpitStyle.mono(.caption))
                        .foregroundStyle(CockpitStyle.muted)
                    Text(section.timeRangeLabel)
                        .font(CockpitStyle.mono(.caption))
                        .cockpitUppercase()
                        .foregroundStyle(CockpitStyle.muted)
                    if isCurrent {
                        Circle().fill(.red).frame(width: 5, height: 5)
                        Text("NOW")
                            .font(CockpitStyle.mono(.caption, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }

                if let summary {
                    Text(summary)
                        .font(CockpitStyle.mono(.caption))
                        .foregroundStyle(CockpitStyle.muted)
                        .lineLimit(2)
                } else if isLoading {
                    loadingDotsView
                } else if allDone && total > 0 {
                    Text("All done ✓")
                        .font(CockpitStyle.mono(.caption))
                        .foregroundStyle(.green)
                } else if total > 0 {
                    Text("\(total - completed) remaining")
                        .font(CockpitStyle.mono(.caption))
                        .foregroundStyle(CockpitStyle.muted)
                } else {
                    Text("Nothing scheduled")
                        .font(CockpitStyle.mono(.caption))
                        .foregroundStyle(CockpitStyle.muted)
                }
            }

            Spacer()

            if total > 0 {
                Text(allDone ? "✓ \(completed)/\(total)" : hasOverdue ? "! \(completed)/\(total)" : "\(completed)/\(total)")
                    .font(CockpitStyle.mono(.caption2, weight: .bold))
                    .foregroundStyle(
                        hasFlagged
                            ? CockpitStyle.inkOnHighlighter
                            : (allDone ? .green : hasOverdue ? Color.orange : CockpitStyle.muted)
                    )
                    .padding(.horizontal, hasFlagged ? 4 : 0)
                    .background(hasFlagged ? CockpitStyle.highlighter : Color.clear)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
    }

    private var loadingDotsView: some View {
        Text("···")
            .font(CockpitStyle.mono(.caption))
            .foregroundStyle(CockpitStyle.muted)
            .phaseAnimator([1.0, 0.3]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
    }

    // MARK: - Row types

    /// A flagged item is called out with a highlighter-yellow background behind its title
    /// instead of a flag icon — the one deliberate behavior swap for this design sprint.
    private func paperPill(
        _ item: PlanItem, showRecurringBadge: Bool = true, isPassed: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            if item.status == .pending {
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        item.status = .completed
                    }
                } label: {
                    Image(systemName: "circle")
                        .foregroundStyle(CockpitStyle.muted)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete \(item.title)")
            }

            // A passed pill keeps the time it was due, which the segments' pills never show.
            if isPassed, let deadline = item.deadline {
                Text(deadline, format: .dateTime.hour().minute())
                    .font(CockpitStyle.mono(.caption2))
                    .foregroundStyle(CockpitStyle.muted)
            }

            Text(item.title)
                .font(CockpitStyle.mono(.subheadline, weight: .semibold))
                .cockpitUppercase()
                .lineLimit(1)
                .foregroundStyle(
                    item.isFlagged
                        ? CockpitStyle.inkOnHighlighter
                        : (item.status == .pending ? CockpitStyle.ink : CockpitStyle.muted)
                )
                .strikethrough(item.status != .pending, color: CockpitStyle.muted)
                .padding(.horizontal, item.isFlagged ? 3 : 0)
                .background(item.isFlagged ? CockpitStyle.highlighter.opacity(0.8) : Color.clear)

            if !item.notes.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption2)
                    .foregroundStyle(CockpitStyle.muted)
            }
            if item.isRecurring && showRecurringBadge {
                Image(systemName: "wrench")
                    .font(.caption2)
                    .foregroundStyle(CockpitStyle.muted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Rectangle().stroke(CockpitStyle.border, lineWidth: 1)
        }
        .italic(isPassed)
        .onTapGesture { itemToEdit = item }
        .contextMenu {
            if isPassed {
                Button { moveToNow([item]) } label: {
                    Label("Move to Now", systemImage: "arrow.uturn.forward")
                }
            }
            Button {
                item.isFlagged.toggle()
                try? modelContext.save()
            } label: {
                Label(item.isFlagged ? "Remove Flag" : "Flag Item", systemImage: item.isFlagged ? "flag.slash" : "flag")
            }
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
                            item.status == .completed ? CockpitStyle.routeBlue : CockpitStyle.border.opacity(0.5),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if item.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(CockpitStyle.routeBlue)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                item.status == .completed ? "Mark \(item.title) as not complete" : "Complete \(item.title)"
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(CockpitStyle.mono(.body, weight: .semibold))
                    .cockpitUppercase()
                    .strikethrough(item.status == .completed)
                    .foregroundStyle(
                        item.isFlagged
                            ? CockpitStyle.inkOnHighlighter
                            : (item.status == .completed ? CockpitStyle.muted : CockpitStyle.ink)
                    )
                    .padding(.horizontal, item.isFlagged ? 3 : 0)
                    .background(item.isFlagged ? CockpitStyle.highlighter.opacity(0.8) : Color.clear)
                if let dl = item.deadline {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2)
                        Text(dl, format: .dateTime.hour().minute())
                            .font(CockpitStyle.mono(.caption2))
                    }
                    .foregroundStyle(CockpitStyle.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
            Button {
                item.isFlagged.toggle()
                try? modelContext.save()
            } label: {
                Label(item.isFlagged ? "Remove Flag" : "Flag Item", systemImage: item.isFlagged ? "flag.slash" : "flag")
            }
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
    CockpitView(viewModel: DayViewModel(), onShowSettings: {}, onShowImport: {})
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#endif

/// The editable flight name. Its own view, so the Cockpit's re-renders don't rebuild the field
/// mid-edit, with the draft started from the stored name.
private struct FlightNameField: View {
    let caption: String
    /// The stored flight number (or the default), shown whenever the field isn't being edited.
    let displayed: String
    let defaultNumber: String
    let commit: (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isFocused: Bool
    /// Raw text while editing, so the field can be emptied without snapping back. It's saved
    /// only when editing ends; saving per keystroke refreshes the `@Query` mid-edit.
    @State private var draft: String
    /// Bound so SwiftUI tracks the caret itself. Without it, on a real iPhone the cursor jumped
    /// to the end of the text on the first edit.
    @State private var selection: TextSelection?

    init(caption: String, displayed: String, defaultNumber: String, commit: @escaping (String) -> Void) {
        self.caption = caption
        self.displayed = displayed
        self.defaultNumber = defaultNumber
        self.commit = commit
        _draft = State(initialValue: displayed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(CockpitStyle.mono(.caption2, weight: .bold))
                .cockpitUppercase()
                .foregroundStyle(CockpitStyle.muted)
            TextField(
                text: $draft,
                selection: $selection,
                prompt: Text(defaultNumber)
                    .font(CockpitStyle.mono(.body, weight: .bold))
                    .foregroundStyle(CockpitStyle.muted)
            ) {
                Text("Flight name")
            }
            .font(CockpitStyle.mono(.body, weight: .bold))
            .foregroundStyle(CockpitStyle.ink)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit { isFocused = false }
            .accessibilityLabel("Flight name")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Pick up changes from elsewhere (e.g. sync) while the field isn't being edited.
        .onChange(of: displayed) { _, displayed in
            if !isFocused { draft = displayed }
        }
        .onChange(of: draft) { _, new in
            if new.count > Day.maxFlightNameLength { draft = String(new.prefix(Day.maxFlightNameLength)) }
        }
        .onChange(of: isFocused) { _, focused in
            guard !focused else { return }
            commit(draft)
            // Blank snaps back to the default number.
            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { draft = defaultNumber }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, isFocused { commit(draft) }
        }
        // Changing days replaces this view (see `.id` at the call site) without reliably
        // reporting the focus loss, so save any unsaved edit on the way out.
        .onDisappear {
            if draft != displayed { commit(draft) }
        }
    }
}
