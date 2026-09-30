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

    /// Day-only component of `instanceDedupeKey`, factored out so the two identity keys below
    /// stay in sync about what "the same day" means.
    private static func dayComponent(of date: Date) -> Double {
        Calendar.current.startOfDay(for: date).timeIntervalSinceReferenceDate
    }

    /// Whether this item already represents `template`'s occurrence for `date` — used to decide
    /// if a template needs a new instance materialized, or if a future-day ghost projection
    /// should be suppressed. Matches only via a *resolved* `template` link, compared by the
    /// template's stable `sourceID` (not title) — so two different templates that happen to
    /// share a title never stand in for each other, and an unrelated one-off item (whose
    /// `template` is always nil) never suppresses a habit just because its title matches. Day
    /// section is never part of the comparison: a drag-moved instance must still count as
    /// covering its template. Returns false when this item's own `template` link hasn't resolved
    /// yet (e.g. mid-CloudKit-sync) — a rare, transient state that can lead to a brief duplicate,
    /// cleaned up by the next `ModelContainer.deduplicateInstances` pass once the relationship
    /// resolves.
    func coversRecurringOccurrence(ofTemplate template: PlanItem, on date: Date) -> Bool {
        guard let linkedTemplate = self.template, linkedTemplate.sourceID == template.sourceID else {
            return false
        }
        return Calendar.current.isDate(self.date, inSameDayAs: date)
    }

    /// Identity key used by `ModelContainer.deduplicateInstances` to catch true duplicate
    /// per-day instances. Recurring instances (with a resolved `template` link) are keyed by the
    /// template's `sourceID` + day — section-independent, so materialization recognizes a
    /// drag-moved instance as still covering its template, and distinct from any other
    /// same-titled template's instances. One-off items keep daySection as part of their identity:
    /// nothing auto-regenerates a one-off item, so two same-titled one-off items in different
    /// sections on the same day are presumed to be genuinely distinct tasks, not duplicates.
    var instanceDedupeKey: String {
        let day = PlanItem.dayComponent(of: date)
        guard let template else {
            return "\(title.lowercased())|\(daySection?.rawValue ?? "")|\(day)"
        }
        return "\(template.sourceID)|\(day)"
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
