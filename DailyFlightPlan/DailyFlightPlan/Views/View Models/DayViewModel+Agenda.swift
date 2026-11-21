//
//  DayViewModel+Agenda.swift
//  DailyFlightPlan
//
// Pure partitioning behind the Cockpit's "Up Next" and "Passed" areas. Every time-specific
// commitment not yet over goes into one chronological Up Next list; anything still open after
// its time or day section ended goes into Passed; everything else stays in its day section.
import Foundation

/// A single row in the Up Next or Passed lists, from any of the three sources.
enum DayEntry: Identifiable {
    case planItem(PlanItem)
    case calendarEvent(CalendarEvent)
    case reminder(ReminderItem)

    var id: String {
        switch self {
        case .planItem(let item):      return "item-\(item.uuid)"
        case .calendarEvent(let event): return "event-\(event.id)"
        case .reminder(let reminder):   return "reminder-\(reminder.id)"
        }
    }
}

/// Where the Cockpit shows each thing on the selected day.
struct DayAgenda {
    /// All-day calendar events, in the order given. They have no time, so they're listed apart
    /// from Up Next and never count as passed.
    var allDay: [CalendarEvent] = []
    /// Timed entries not yet over, soonest first. An in-progress calendar event counts as upcoming.
    var upcoming: [DayEntry] = []
    /// Open entries whose time or day section has ended, oldest first.
    var passed: [DayEntry] = []
    /// What stays in the day sections and Open area (see `DayViewModel.agenda`).
    var sectionItems: [PlanItem] = []
}

/// A stretch of the Passed list in one row style: consecutive plan items share a flow layout of
/// pills, while each reminder is its own row. Keeps the list oldest first across both styles.
enum PassedRun: Identifiable {
    case pills([PlanItem])
    case reminder(ReminderItem)

    var id: String {
        switch self {
        case .pills(let items): return "pills-\(items.first?.uuid.uuidString ?? "")"
        case .reminder(let reminder): return "reminder-\(reminder.id)"
        }
    }
}

extension DayViewModel {

    /// Groups `entries` (already oldest first) into runs without reordering them. Calendar events
    /// never appear in Passed, so any that sneak in are skipped.
    func passedRuns(from entries: [DayEntry]) -> [PassedRun] {
        var runs: [PassedRun] = []
        var pending: [PlanItem] = []
        func flushPills() {
            guard !pending.isEmpty else { return }
            runs.append(.pills(pending))
            pending = []
        }
        for entry in entries {
            switch entry {
            case .planItem(let item):
                pending.append(item)
            case .reminder(let reminder):
                flushPills()
                runs.append(.reminder(reminder))
            case .calendarEvent:
                continue
            }
        }
        flushPills()
        return runs
    }

    private enum Slot {
        case upcoming, passed, section
    }

    /// Splits `items`, `events`, and `reminders` between Up Next, Passed, and the day sections.
    ///
    /// Passed (today only) holds things whose moment has gone: plan items with a deadline that
    /// are past it and pending; untimed plan items, recurring (Maintenance) ones included, whose
    /// day section has ended; and every reminder whose due time has passed, open or completed
    /// (a completed one only shows when the Completed filter lets it through).
    ///
    /// Up Next holds timed entries that aren't over: plan items before their deadline, reminders
    /// before their due time, and events until they end (so one in progress still shows). On any
    /// day other than today every timed entry is upcoming.
    ///
    /// Calendar events that have ended are dropped: they can't be acted on, so they appear
    /// nowhere once over.
    ///
    /// Everything else stays in its day section: untimed items, plus completed or canceled plan
    /// items whose time has passed. Reminders without a due time are left out, as the Open area
    /// shows those.
    func agenda(items: [PlanItem], events: [CalendarEvent], reminders: [ReminderItem]) -> DayAgenda {
        var upcoming: [(time: Date, entry: DayEntry)] = []
        var passed: [(time: Date, entry: DayEntry)] = []
        var agenda = DayAgenda()

        for item in items {
            switch slot(for: item) {
            case .upcoming:
                upcoming.append((item.deadline ?? currentTime, .planItem(item)))
            case .passed:
                let time = item.deadline ?? item.daySection.map(sectionEndTime) ?? currentTime
                passed.append((time, .planItem(item)))
            case .section:
                agenda.sectionItems.append(item)
            }
        }

        for event in events {
            if event.isAllDay {
                agenda.allDay.append(event)
                continue
            }
            // An event that has ended is dropped entirely rather than filed anywhere.
            if isToday && event.endDate <= currentTime { continue }
            upcoming.append((event.startDate, .calendarEvent(event)))
        }

        for reminder in reminders {
            guard let due = reminder.dueDate else { continue }
            if isToday && due < currentTime {
                passed.append((due, .reminder(reminder)))
            } else {
                upcoming.append((due, .reminder(reminder)))
            }
        }

        // Ties fall back to the id so the order is deterministic across recomputes.
        agenda.upcoming = upcoming
            .sorted { ($0.time, $0.entry.id) < ($1.time, $1.entry.id) }
            .map(\.entry)
        agenda.passed = passed
            .sorted { ($0.time, $0.entry.id) < ($1.time, $1.entry.id) }
            .map(\.entry)
        return agenda
    }

    /// The items from `items` that stay in the day sections and Open area, rather than being
    /// listed in Up Next or Passed. Lets progress counts match what the sections show.
    func sectionItems(from items: [PlanItem]) -> [PlanItem] {
        items.filter { slot(for: $0) == .section }
    }

    /// Whether `section` has anything to list: untimed plan items assigned to it, or completed
    /// ones that came due in it. Calendar events and reminders never count, since they live in
    /// Up Next or Passed (or, once an event is over, nowhere), and neither do items that moved to
    /// Up Next or Passed, so a past segment is empty once nothing but completed items are left.
    func hasContent(_ section: DaySection, in agenda: DayAgenda) -> Bool {
        !sectionPills(section, from: agenda.sectionItems).isEmpty
            || !deadlineRows(section, from: agenda.sectionItems).isEmpty
    }

    /// Whether dropping `item` onto `section` (nil = Open) should be accepted. An open item
    /// dropped on a segment that has already ended would immediately count as passed again, so
    /// that drop is refused rather than shuffling the item back into Passed.
    func canMove(_ item: PlanItem, to section: DaySection?) -> Bool {
        guard let section, item.status == .pending else { return true }
        return !isSectionOver(section)
    }

    /// When `entry` starts, for the "in 42 min" countdown on the next upcoming entry.
    func startTime(of entry: DayEntry) -> Date {
        switch entry {
        case .planItem(let item):       return item.deadline ?? currentTime
        case .calendarEvent(let event): return event.startDate
        case .reminder(let reminder):   return reminder.dueDate ?? currentTime
        }
    }

    /// "now" once the entry has started, otherwise "in 42 min" / "in 1h 20m".
    func countdownLabel(for entry: DayEntry) -> String {
        let remaining = startTime(of: entry).timeIntervalSince(currentTime)
        guard remaining > 0 else { return "now" }
        let minutes = Int((remaining / 60).rounded(.up))
        guard minutes >= 60 else { return "in \(minutes) min" }
        let hours = minutes / 60
        let leftover = minutes % 60
        return leftover == 0 ? "in \(hours)h" : "in \(hours)h \(leftover)m"
    }

    private func slot(for item: PlanItem) -> Slot {
        // Canceled items are never listed as upcoming or passed; they only show (in their
        // section) when the "Completed" filter reveals them.
        guard item.status != .canceled else { return .section }
        guard let deadline = item.deadline else {
            return isSectionMissed(item) ? .passed : .section
        }
        guard isToday && deadline < currentTime else { return .upcoming }
        return item.status == .pending ? .passed : .section
    }

    /// Whether `section` has ended, viewing today. The first thing past 7:29 AM is Morning.
    func isSectionOver(_ section: DaySection) -> Bool {
        isToday && sectionEndTime(section) < currentTime
    }

    /// The last moment of `section` on the day of `currentTime`.
    func sectionEndTime(_ section: DaySection) -> Date {
        Calendar.current.date(
            bySettingHour: section.endMinutes / 60, minute: section.endMinutes % 60,
            second: 59, of: currentTime
        ) ?? currentTime
    }
}

/// What the Cockpit lists for a day that's over: a read-only record of its plan items, rather
/// than a live agenda. Calendar events and Reminders aren't part of it.
struct PastDayReport {
    /// Completed plan items, earliest first.
    var completed: [PlanItem] = []
    /// Plan items left open, earliest first.
    var missed: [PlanItem] = []
    /// Canceled plan items, earliest first.
    var canceled: [PlanItem] = []

    var isEmpty: Bool {
        completed.isEmpty && missed.isEmpty && canceled.isEmpty
    }
}

extension DayViewModel {

    /// Files `items` into the sections of a past day's report. Unlike
    /// `agenda(items:events:reminders:)` there's no live clock to split on, so status alone
    /// decides: an item is completed, missed (still pending), or canceled.
    ///
    /// Each list runs earliest first by deadline, with untimed items last. Ties fall back to the
    /// title, then the id, so the order is deterministic across recomputes.
    func pastDayReport(items: [PlanItem]) -> PastDayReport {
        func ordered(_ items: [PlanItem]) -> [PlanItem] {
            items.sorted {
                ($0.deadline ?? .distantFuture, $0.title, $0.uuid.uuidString)
                    < ($1.deadline ?? .distantFuture, $1.title, $1.uuid.uuidString)
            }
        }
        return PastDayReport(
            completed: ordered(items.filter { $0.status == .completed }),
            missed: ordered(items.filter { $0.status == .pending }),
            canceled: ordered(items.filter { $0.status == .canceled })
        )
    }
}
