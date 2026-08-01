//
//  PlanItem.swift
//  DailyFlightPlan
//
import SwiftData
import Foundation

@Model
class PlanItem {

    var title: String
    var notes: String
    var isFlagged: Bool

    /// The calendar day this item belongs to
    var date: Date

    /// A specific clock-time deadline. nil means the item is not time-specific.
    var deadline: Date?

    /// The time-of-day section this item is associated with.
    /// nil when the item has a specific deadline or is explicitly "any time".
    var daySection: DaySection?

    var isRecurring: Bool

    /// The weekdays on which this item recurs
    var recurringWeekdays: [Locale.Weekday]

    var status: ItemStatus

    @Relationship(deleteRule: .nullify, inverse: \PlanCategory.items)
    var categories: [PlanCategory]

    init(
        title: String,
        notes: String = "",
        isFlagged: Bool = false,
        date: Date = .now,
        deadline: Date? = nil,
        daySection: DaySection? = nil,
        isRecurring: Bool = false,
        recurringWeekdays: [Locale.Weekday] = [],
        status: ItemStatus = .pending,
        categories: [PlanCategory] = []
    ) {
        self.title = title
        self.notes = notes
        self.isFlagged = isFlagged
        self.date = date
        self.deadline = deadline
        self.daySection = daySection
        self.isRecurring = isRecurring
        self.recurringWeekdays = recurringWeekdays
        self.status = status
        self.categories = categories
    }
}
