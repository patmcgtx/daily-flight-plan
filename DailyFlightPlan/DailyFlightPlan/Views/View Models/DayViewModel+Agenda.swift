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
    /// Timed entries not yet over, soonest first. An in-progress calendar event counts as upcoming.
    var upcoming: [DayEntry] = []
    /// Open entries whose time or day section has ended, oldest first.
    var passed: [DayEntry] = []
    /// What stays in the day sections and Open area (see `DayViewModel.agenda`).
    var sectionItems: [PlanItem] = []
    var sectionEvents: [CalendarEvent] = []
    var sectionReminders: [ReminderItem] = []
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
    /// Passed (today only) holds things still open once their moment has gone: plan items with a
    /// deadline, and reminders with a due time, that are past it and pending; and untimed plan
    /// items, recurring (Maintenance) ones included, whose day section has ended. Calendar events
    /// are never passed — they can't be completed.
    ///
    /// Up Next holds timed entries that aren't over: plan items before their deadline, reminders
    /// before their due time, and events until they end (so one in progress still shows). On any
    /// day other than today every timed entry is upcoming.
    ///
    /// Everything else stays in its day section: untimed items, plus ended events and completed
    /// or canceled items whose time has passed. Reminders without a due time are left out, as
    /// the Open area shows those.
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
            if isToday && event.endDate <= currentTime {
                agenda.sectionEvents.append(event)
            } else {
                upcoming.append((event.startDate, .calendarEvent(event)))
            }
        }

        for reminder in reminders {
            guard let due = reminder.dueDate else { continue }
            if isToday && due < currentTime {
                if reminder.isCompleted {
                    agenda.sectionReminders.append(reminder)
                } else {
                    passed.append((due, .reminder(reminder)))
                }
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

    /// Whether `section` has anything to list: untimed items assigned to it, completed items that
    /// came due in it, ended calendar events, or completed reminders. Items that moved to Up Next
    /// or Passed don't count, so a past segment is empty once nothing but history is left in it.
    func hasContent(_ section: DaySection, in agenda: DayAgenda) -> Bool {
        !sectionPills(section, from: agenda.sectionItems).isEmpty
            || !deadlineRows(section, from: agenda.sectionItems).isEmpty
            || !calendarEventsForSection(section, from: agenda.sectionEvents).isEmpty
            || !reminderItemsForSection(section, from: agenda.sectionReminders).isEmpty
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
