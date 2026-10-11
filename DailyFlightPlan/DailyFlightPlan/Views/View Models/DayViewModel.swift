//
//  DayViewModel.swift
//  DailyFlightPlan
//
import SwiftUI
import FoundationModels

@Observable @MainActor
final class DayViewModel {

    var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    var collapsedSections: Set<DaySection> = []
    private(set) var forwardNavigation: Bool = true
    private(set) var sectionSummaries: [DaySection: String] = [:]

    // Updated each minute by startLiveClock(); drives currentSection and Past area in real time.
    private(set) var currentTime: Date = .now
    private(set) var loadingSummarySections: Set<DaySection> = []
    private var clockTask: Task<Void, Never>?
    private var summaryTasks: [DaySection: Task<Void, Never>] = [:]
    private var sectionContentSignatures: [DaySection: String] = [:]
    // Identifies which generation of a section's summary task is current. A canceled task
    // whose generation no longer matches must not clear shared state or publish its result —
    // otherwise it can clobber a newer in-flight (or already-completed) generation.
    private var summaryGenerations: [DaySection: UUID] = [:]

    /// `currentTime` defaults to the real clock but can be injected for deterministic testing.
    init(currentTime: Date = .now) {
        self.currentTime = currentTime
    }

    // MARK: Date helpers

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// The section that contains the current clock time, or nil if not viewing today
    var currentSection: DaySection? {
        guard isToday else { return nil }
        return DaySection.containing(currentTime)
    }

    /// Sections whose time window has already ended when viewing today. Empty on other days.
    var pastSections: [DaySection] {
        guard isToday,
              let current = currentSection,
              let currentIdx = DaySection.allCases.firstIndex(of: current) else { return [] }
        return Array(DaySection.allCases.prefix(currentIdx))
    }

    /// All six sections, always — past sections remain visible for day-at-a-glance reference.
    var activeSections: [DaySection] {
        DaySection.allCases
    }

    func goToYesterday() {
        guard let date = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        forwardNavigation = false
        selectedDate = date
    }

    func goToTomorrow() {
        guard let date = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        forwardNavigation = true
        selectedDate = date
    }

    func goToToday() {
        let today = Calendar.current.startOfDay(for: .now)
        forwardNavigation = selectedDate < today
        selectedDate = today
    }

    func navigate(to date: Date) {
        let target = Calendar.current.startOfDay(for: date)
        guard target != selectedDate else { return }
        forwardNavigation = target > selectedDate
        selectedDate = target
    }

    // MARK: Section collapse

    func isCollapsed(_ section: DaySection) -> Bool {
        collapsedSections.contains(section)
    }

    func toggleCollapsed(_ section: DaySection) {
        if collapsedSections.contains(section) {
            collapsedSections.remove(section)
        } else {
            collapsedSections.insert(section)
        }
    }

    // MARK: Live clock

    /// Starts a per-minute background tick that updates currentTime, keeping the Past area current.
func startLiveClock() {
        guard clockTask == nil else { return }
        clockTask = Task { @MainActor [weak self] in
            defer { self?.clockTask = nil }
            while !Task.isCancelled {
                let now = Date.now
                var components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: now
                )
                components.minute = (components.minute ?? 0) + 1
                components.second = 0
                components.nanosecond = 0
                let nextMinute = Calendar.current.date(from: components) ?? now.addingTimeInterval(60)
                let sleepSeconds = max(1, nextMinute.timeIntervalSince(Date.now))
                do {
                    try await Task.sleep(for: .seconds(sleepSeconds))
                } catch {
                    return
                }
                withAnimation(.spring(duration: 0.3)) {
                    self?.currentTime = .now
                    if let current = self?.currentSection {
                        self?.collapsedSections.remove(current)
                    }
                }
            }
        }
    }

    // MARK: Missed item logic

    /// Returns true only for items with a specific clock-time deadline that has now passed.
    /// Section-assigned items without a deadline stay in their section card regardless of time.
    func isMissed(_ item: PlanItem) -> Bool {
        isDeadlineMissed(item)
    }

    /// Item had a specific timed deadline that has now passed → shown in "Missed".
    func isDeadlineMissed(_ item: PlanItem) -> Bool {
        guard isToday, item.status == .pending, let deadline = item.deadline else { return false }
        return deadline < currentTime
    }

    /// Item was assigned to a day section that has ended, with no specific deadline → shown in "Any Time".
    private func isSectionMissed(_ item: PlanItem) -> Bool {
        guard isToday, item.status == .pending, item.deadline == nil,
              let section = item.daySection,
              let sectionEnd = Calendar.current.date(
                  bySettingHour: section.endHour, minute: 59, second: 59, of: currentTime
              ) else { return false }
        return sectionEnd < currentTime
    }

    // MARK: Item grouping

    /// Items assigned to this section (excluding missed items, which fall to "any time")
    func sectionPills(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.daySection == section && !isMissed($0) }
    }

    /// Deadline items whose clock time falls within this section (excluding missed items)
    func deadlineRows(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items
            .filter { item in
                guard let deadline = item.deadline, item.daySection == nil, !isMissed(item) else { return false }
                return DaySection.containing(deadline) == section
            }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    // MARK: Projected recurring items (future dates)

    /// Recurring templates that should appear as ghost previews on a future date.
    /// Excludes templates that already have a materialized instance for that date.
    func projectedRecurringItems(for date: Date, from templates: [PlanItem]) -> [PlanItem] {
        guard Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: .now) else { return [] }
        guard let weekday = localeWeekday(of: date) else { return [] }
        return templates.filter { template in
            guard template.isTemplate,
                  template.daySection != nil,
                  template.recurringWeekdays.contains(weekday) else { return false }
            let instances = template.instances ?? []
            return !instances.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
        }
    }

    private func localeWeekday(of date: Date) -> Locale.Weekday? {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    // MARK: Recurring instance materialization (today)

    /// Builds per-day instances for templates that match `date`'s weekday and have no existing
    /// instance for that date, given a fresh fetch of templates and same-day items. Pure — the
    /// caller is responsible for inserting the returned instances into the model context and saving.
    ///
    /// Coverage is determined by `PlanItem.coversRecurringOccurrence`, which matches by the
    /// template's identity (not just title) and ignores day section: a drag-moved instance must
    /// still count as covering its template, but a *different* same-titled template's instance
    /// — or an unrelated one-off item that happens to share a title — must not.
    func recurringInstancesToMaterialize(
        for date: Date,
        templates: [PlanItem],
        existingItemsForDate: [PlanItem]
    ) -> [PlanItem] {
        guard let weekday = localeWeekday(of: date) else { return [] }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)

        var newInstances: [PlanItem] = []
        for template in templates where template.isTemplate {
            guard template.recurringWeekdays.contains(weekday) else { continue }
            let isCovered = existingItemsForDate.contains { $0.coversRecurringOccurrence(ofTemplate: template, on: date) }
            guard !isCovered else { continue }
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
            newInstances.append(instance)
        }
        return newInstances
    }

    // MARK: Calendar events

    /// Calendar events whose start time falls within this section
    func calendarEventsForSection(_ section: DaySection, from events: [CalendarEvent]) -> [CalendarEvent] {
        events.filter { DaySection.containing($0.startDate) == section }
    }

    /// Calendar events belonging to any past section (shown in the "Past" card at the top of today's view)
    func pastCalendarEvents(from events: [CalendarEvent]) -> [CalendarEvent] {
        let past = Set(pastSections)
        return events.filter { event in
            guard let section = DaySection.containing(event.startDate) else { return false }
            return past.contains(section)
        }
    }

    /// Timed reminders belonging to any past section (shown in the "Missed" card)
    func pastReminderItems(from items: [ReminderItem]) -> [ReminderItem] {
        let past = Set(pastSections)
        return items.filter { item in
            guard let dueDate = item.dueDate,
                  let section = DaySection.containing(dueDate) else { return false }
            return past.contains(section)
        }
    }

    /// Reminders with a specific due time that falls within this section
    func reminderItemsForSection(_ section: DaySection, from items: [ReminderItem]) -> [ReminderItem] {
        items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return DaySection.containing(dueDate) == section
        }
    }

    /// Reminders with no specific due time (shown in the "Any Time" area)
    func anyTimeReminderItems(from items: [ReminderItem]) -> [ReminderItem] {
        items.filter { $0.dueDate == nil }
    }

    /// Pending items whose specific deadline has passed — shown in the "Missed" section.
    func missedDeadlineItems(from items: [PlanItem]) -> [PlanItem] {
        items.filter { isDeadlineMissed($0) }
            .sorted { ($0.deadline ?? .distantPast) < ($1.deadline ?? .distantPast) }
    }

    /// Truly untimed items — no section assignment and no deadline.
    func anyTimeItems(from items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.daySection == nil && $0.deadline == nil }
    }

    /// The earliest upcoming deadline among pending items for a given date — preferring ones
    /// still ahead of `currentTime` when `referenceDate` is today, falling back to the day's
    /// earliest deadline otherwise (e.g. a past day, or a today whose remaining deadlines have
    /// all slipped by).
    func nextUpcomingDeadline(from items: [PlanItem], referenceDate: Date) -> Date? {
        let pendingWithDeadline = items.filter { $0.status == .pending && $0.deadline != nil }
        guard !pendingWithDeadline.isEmpty else { return nil }
        let isReferenceToday = Calendar.current.isDateInToday(referenceDate)
        let upcoming = isReferenceToday ? pendingWithDeadline.filter { $0.deadline! >= currentTime } : pendingWithDeadline
        let pool = upcoming.isEmpty ? pendingWithDeadline : upcoming
        return pool.min(by: { $0.deadline! < $1.deadline! })?.deadline
    }

    /// Count of pending items flagged as a priority.
    func outstandingFlaggedCount(from items: [PlanItem]) -> Int {
        items.filter { $0.isFlagged && $0.status == .pending }.count
    }

    // MARK: Auto-collapse and AI summaries

    /// Collapse all inactive sections when viewing today. No-op on past/future dates.
    func applyAutoCollapse() {
        guard isToday else {
            collapsedSections = []
            return
        }
        collapsedSections = Set(activeSections.filter { $0 != currentSection })
    }

    /// Clear a single section's cached summary and cancel any in-flight task, allowing regeneration.
    func clearSummary(for section: DaySection) {
        summaryTasks[section]?.cancel()
        summaryTasks[section] = nil
        sectionSummaries[section] = nil
        sectionContentSignatures[section] = nil
        loadingSummarySections.remove(section)
    }

    /// Cancel any in-flight summary tasks and clear cached summaries (call on date change).
    func clearSummaries() {
        summaryTasks.values.forEach { $0.cancel() }
        summaryTasks = [:]
        summaryGenerations = [:]
        sectionSummaries = [:]
        sectionContentSignatures = [:]
        loadingSummarySections = []
    }

    /// A string that changes whenever the set or state of items/events/reminders feeding a
    /// section's summary changes — membership (moved in/out), status (e.g. canceled), title,
    /// or timing. Used to detect that a cached summary is stale and needs regenerating.
    func contentSignature(items: [PlanItem], events: [CalendarEvent], reminders: [ReminderItem]) -> String {
        let itemPart = items
            .sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            .map { "\($0.uuid)|\($0.status.rawValue)|\($0.title)|\($0.deadline?.timeIntervalSinceReferenceDate ?? 0)" }
            .joined(separator: ",")
        let eventPart = events
            .sorted { $0.id < $1.id }
            .map { "\($0.id)|\($0.title)|\($0.startDate.timeIntervalSinceReferenceDate)" }
            .joined(separator: ",")
        let reminderPart = reminders
            .sorted { $0.id < $1.id }
            .map { "\($0.id)|\($0.title)|\($0.isCompleted)|\($0.dueDate?.timeIntervalSinceReferenceDate ?? 0)" }
            .joined(separator: ",")
        return [itemPart, eventPart, reminderPart].joined(separator: "||")
    }

    /// Regenerates a section's summary if its content has changed since the last generation
    /// (items moved in/out, canceled, titles/deadlines edited, etc.), then generates it if needed.
    func refreshSummaryIfNeeded(
        for section: DaySection,
        items: [PlanItem],
        events: [CalendarEvent],
        reminders: [ReminderItem]
    ) {
        let signature = contentSignature(items: items, events: events, reminders: reminders)
        if let previous = sectionContentSignatures[section], previous != signature {
            clearSummary(for: section)
        }
        sectionContentSignatures[section] = signature
        generateSummaryIfNeeded(for: section, items: items, events: events, reminders: reminders)
    }

    /// Generate a one-line AI summary for a collapsed section. Skips if already cached or in-flight.
    func generateSummaryIfNeeded(
        for section: DaySection,
        items: [PlanItem],
        events: [CalendarEvent],
        reminders: [ReminderItem]
    ) {
        guard sectionSummaries[section] == nil, summaryTasks[section] == nil else { return }
        guard !items.isEmpty || !events.isEmpty || !reminders.isEmpty else { return }
        guard SystemLanguageModel.default.availability == .available else { return }

        let generation = UUID()
        summaryGenerations[section] = generation
        loadingSummarySections.insert(section)
        summaryTasks[section] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                // A canceled predecessor's defer must not clobber a newer generation that has
                // already taken over this section's task/loading state.
                if self.summaryGenerations[section] == generation {
                    self.summaryTasks[section] = nil
                    self.loadingSummarySections.remove(section)
                }
            }

            guard !Task.isCancelled else { return }

            let session = LanguageModelSession(
                instructions: "Summarize listed items in under 10 words. Use very short phrases joined by · (middle dot). Items marked (done) are already completed — reflect that rather than treating them as upcoming. Be factual and concise. Output a single line only — no newlines, no bullet points, no lists."
            )

            func label(_ title: String, done: Bool) -> String {
                done ? "\(title) (done)" : title
            }

            // All timed items merged and sorted by clock time — deadline plan items,
            // calendar events, and timed reminders are equally time-sensitive. Completed
            // items are included (marked done) so a fully-finished section still has enough
            // material for a coherent summary; canceled items are excluded entirely.
            struct TimedEntry {
                let time: Date
                let label: String
            }
            var timedEntries: [TimedEntry] = []
            for item in items where item.deadline != nil && item.status != .canceled {
                if let dl = item.deadline {
                    let text = label(item.title, done: item.status == .completed)
                    timedEntries.append(TimedEntry(time: dl, label: "\(text) at \(dl.formatted(.dateTime.hour().minute()))"))
                }
            }
            for event in events {
                timedEntries.append(TimedEntry(time: event.startDate, label: "\(event.title) at \(event.startDate.formatted(.dateTime.hour().minute()))"))
            }
            for reminder in reminders where reminder.dueDate != nil {
                if let due = reminder.dueDate {
                    let text = label(reminder.title, done: reminder.isCompleted)
                    timedEntries.append(TimedEntry(time: due, label: "\(text) at \(due.formatted(.dateTime.hour().minute()))"))
                }
            }
            timedEntries.sort { $0.time < $1.time }

            var parts = timedEntries.prefix(6).map(\.label)

            // Non-recurring items without a fixed time — completed included (marked done), canceled excluded
            let oneOffItems = items.filter { $0.deadline == nil && $0.status != .canceled && !$0.isRecurring }
            for item in oneOffItems.prefix(4) {
                parts.append(label(item.title, done: item.status == .completed))
            }

            // Untimed reminders
            for reminder in reminders.filter({ $0.dueDate == nil }).prefix(4) {
                parts.append(label(reminder.title, done: reminder.isCompleted))
            }

            // Recurring habits — least surprising, capped tightly; completed included (marked done)
            let habitItems = items.filter { $0.deadline == nil && $0.status != .canceled && $0.isRecurring }
            for item in habitItems.prefix(2) {
                parts.append(label(item.title, done: item.status == .completed))
            }

            guard !parts.isEmpty else { return }

            let prompt = parts.joined(separator: "; ")
            if let response = try? await session.respond(to: prompt),
               !Task.isCancelled, self.summaryGenerations[section] == generation {
                self.sectionSummaries[section] = response.content
                    .components(separatedBy: .newlines)
                    .joined(separator: " · ")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
    }

}
