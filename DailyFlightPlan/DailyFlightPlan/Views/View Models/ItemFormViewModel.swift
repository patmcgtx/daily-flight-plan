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
    var isRecurring: Bool
    var recurringWeekdays: [Locale.Weekday]
    var selectedCategories: [PlanCategory]

    private let editingItem: PlanItem?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(date: Date) {
        editingItem = nil
        title = ""
        notes = ""
        isFlagged = false
        self.date = Calendar.current.startOfDay(for: date)
        daySection = nil
        hasDeadline = false
        deadline = date
        isRecurring = false
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
        isRecurring = item.isRecurring
        recurringWeekdays = item.recurringWeekdays
        selectedCategories = item.categories
    }

    func save(in context: ModelContext) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if let item = editingItem {
            item.title = trimmedTitle
            item.notes = notes
            item.isFlagged = isFlagged
            item.date = date
            item.deadline = hasDeadline ? deadline : nil
            item.daySection = hasDeadline ? nil : daySection
            item.isRecurring = isRecurring
            item.recurringWeekdays = isRecurring ? recurringWeekdays : []
            item.categories = selectedCategories
        } else {
            let newItem = PlanItem(
                title: trimmedTitle,
                notes: notes,
                isFlagged: isFlagged,
                date: date,
                deadline: hasDeadline ? deadline : nil,
                daySection: hasDeadline ? nil : daySection,
                isRecurring: isRecurring,
                recurringWeekdays: isRecurring ? recurringWeekdays : []
            )
            newItem.categories = selectedCategories
            context.insert(newItem)
        }

        try? context.save()
    }
}
