//
//  PlanItem.swift
//  DailyFlightPlan
//
import SwiftData
import Foundation

@Model
class PlanItem {

    /// Cross-device deduplication key. Seeded templates use a deterministic string so all
    /// devices converge to one copy after CloudKit sync. User-created items get a random UUID.
    var sourceID: String = UUID().uuidString

    /// Stable identifier used for drag-and-drop payload. Separate from SwiftData's persistentModelID.
    var uuid: UUID = UUID()

    var title: String = "Unknown"
    var notes: String = ""
    var isFlagged: Bool = false

    /// The calendar day this item belongs to
    var date: Date = Date()

    /// A specific clock-time deadline. nil means the item is not time-specific.
    var deadline: Date?

    /// The time-of-day section this item is associated with.
    /// nil when the item has a specific deadline or is explicitly "any time".
    var daySection: DaySection?

    /// The recurring schedule. Only meaningful when isTemplate is true.
    var recurringWeekdays: [Locale.Weekday] = []

    /// True for recurring item templates. False for one-off items and per-day instances.
    var isTemplate: Bool = false

    /// The template this instance was generated from, or nil for one-off items and templates.
    var template: PlanItem? = nil

    /// All per-day instances generated from this template. Only populated on templates.
    @Relationship(deleteRule: .nullify, inverse: \PlanItem.template)
    var instances: [PlanItem]?

    /// True if this item is a recurring template, or a per-day instance of one.
    var isRecurring: Bool {
        isTemplate || template != nil
    }

    /// Identity key for "this day's occurrence" of a *recurring* item — used to check whether a
    /// template already has an instance for a given date, and to de-duplicate recurring
    /// instances. Deliberately excludes daySection: a recurring instance's section is a mutable
    /// placement (e.g. dragged between sections) and must not affect which occurrence it is, or
    /// a moved instance gets duplicated back into the template's original section on the next
    /// materialization pass. Does not apply to template identity, which is a schedule definition
    /// (see `ModelContainer.templateContentKey`), not a single day's occurrence — nor to one-off
    /// items (see `instanceDedupeKey` below), which have no template to duplicate them back.
    static func dailyOccurrenceKey(title: String, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSinceReferenceDate
        return "\(title.lowercased())|\(day)"
    }

    var dailyOccurrenceKey: String {
        PlanItem.dailyOccurrenceKey(title: title, date: date)
    }

    /// Identity key used by `ModelContainer.deduplicateInstances` to catch true duplicate
    /// per-day instances. Recurring instances (with a resolved `template` link) are keyed
    /// section-independently via `dailyOccurrenceKey`, since materialization must recognize a
    /// drag-moved instance as still covering its template. One-off items keep daySection as part
    /// of their identity: nothing auto-regenerates a one-off item, so two same-titled one-off
    /// items in different sections on the same day are presumed to be genuinely distinct tasks,
    /// not duplicates.
    var instanceDedupeKey: String {
        guard template != nil else {
            let day = Calendar.current.startOfDay(for: date).timeIntervalSinceReferenceDate
            return "\(title.lowercased())|\(daySection?.rawValue ?? "")|\(day)"
        }
        return dailyOccurrenceKey
    }

    var status: ItemStatus = ItemStatus.pending

    @Relationship(deleteRule: .nullify, inverse: \PlanCategory.items)
    var categories: [PlanCategory]?

    /// The EventKit reminder identifier this item was synced from, if any.
    var reminderIdentifier: String?

    init(
        title: String,
        notes: String = "",
        isFlagged: Bool = false,
        date: Date = .now,
        deadline: Date? = nil,
        daySection: DaySection? = nil,
        recurringWeekdays: [Locale.Weekday] = [],
        isTemplate: Bool = false,
        status: ItemStatus = .pending,
        categories: [PlanCategory] = [],
        sourceID: String = UUID().uuidString
    ) {
        self.title = title
        self.notes = notes
        self.isFlagged = isFlagged
        self.date = date
        self.deadline = deadline
        self.daySection = daySection
        self.recurringWeekdays = recurringWeekdays
        self.isTemplate = isTemplate
        self.status = status
        self.categories = categories
        self.sourceID = sourceID
    }
}
