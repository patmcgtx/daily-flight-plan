//
//  ItemFormViewModel.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

@Observable @MainActor final class ItemFormViewModel {

    var title: String
    var notes: String
    var isFlagged: Bool
    var date: Date
    var daySection: DaySection?
    var hasDeadline: Bool
    var deadline: Date
    var recurringWeekdays: [Locale.Weekday]
    var selectedCategories: [PlanCategory]

    private let editingItem: PlanItem?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True when editing a per-day instance (not a template or one-off item).
    var isEditingInstance: Bool { editingItem?.template != nil }

    /// True when editing a recurring template.
    var isEditingTemplate: Bool { editingItem?.isTemplate == true }

    init(date: Date) {
        editingItem = nil
        title = ""
        notes = ""
        isFlagged = false
        self.date = Calendar.current.startOfDay(for: date)
        daySection = nil
        hasDeadline = false
        deadline = date
        recurringWeekdays = []
        selectedCategories = []
    }

    init(item: PlanItem) {
        editingItem = item
        title = item.title
        notes = item.notes
        isFlagged = item.isFlagged
        date = item.date
        daySection = item.daySection
        hasDeadline = item.deadline != nil
        deadline = item.deadline ?? item.date
        // Instances inherit their schedule from the template; show nothing in the picker.
        recurringWeekdays = item.isTemplate ? item.recurringWeekdays : []
        selectedCategories = item.categories
    }

    func save(in context: ModelContext) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let alignedDeadline: Date? = {
            guard hasDeadline else { return nil }
            let hour = cal.component(.hour, from: deadline)
            let minute = cal.component(.minute, from: deadline)
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }()

        if let item = editingItem {
            item.title = trimmedTitle
            item.notes = notes
            item.isFlagged = isFlagged
            item.deadline = alignedDeadline
            item.daySection = hasDeadline ? nil : daySection
            item.categories = selectedCategories
            // Only templates and one-off items own their date and recurring schedule.
            if !isEditingInstance {
                item.date = day
                item.recurringWeekdays = recurringWeekdays
                item.isTemplate = !recurringWeekdays.isEmpty
            }
        } else {
            let isRecurring = !recurringWeekdays.isEmpty
            let newItem = PlanItem(
                title: trimmedTitle,
                notes: notes,
                isFlagged: isFlagged,
                date: day,
                deadline: alignedDeadline,
                daySection: hasDeadline ? nil : daySection,
                recurringWeekdays: recurringWeekdays,
                isTemplate: isRecurring
            )
            newItem.categories = selectedCategories
            context.insert(newItem)
            // Instances for this new template are materialized by DayView on sheet dismissal.
        }

        try? context.save()
    }
}
