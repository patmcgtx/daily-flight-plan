//
//  ItemFormViewModelTests.swift
//  DailyFlightPlanTests
//

import Testing
import SwiftData
import Foundation
@testable import DailyFlightPlan

@Suite(.serialized)
@MainActor
struct ItemFormViewModelTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PlanItem.self, PlanCategory.self, configurations: config)
        return ModelContext(container)
    }

    private func fetchItems(_ context: ModelContext) throws -> [PlanItem] {
        try context.fetch(FetchDescriptor<PlanItem>())
    }

    // MARK: isValid

    @Test("isValid is true only when the title has non-whitespace content", arguments: [
        ("Buy milk", true),
        ("", false),
        ("   ", false),
        ("  Buy milk  ", true),
    ])
    func isValid(title: String, expected: Bool) {
        let viewModel = ItemFormViewModel(date: .now)
        viewModel.title = title
        #expect(viewModel.isValid == expected)
    }

    // MARK: Editing-kind flags

    @Test("isEditingInstance and isEditingTemplate reflect the kind of item being edited")
    func editingKindFlags() {
        let oneOff = PlanItem(title: "One-off", date: .now)
        let oneOffViewModel = ItemFormViewModel(item: oneOff)
        #expect(!oneOffViewModel.isEditingInstance)
        #expect(!oneOffViewModel.isEditingTemplate)

        let template = PlanItem(title: "Template", date: .now, recurringWeekdays: [.monday], isTemplate: true)
        let templateViewModel = ItemFormViewModel(item: template)
        #expect(!templateViewModel.isEditingInstance)
        #expect(templateViewModel.isEditingTemplate)

        let instance = PlanItem(title: "Instance", date: .now)
        instance.template = template
        let instanceViewModel = ItemFormViewModel(item: instance)
        #expect(instanceViewModel.isEditingInstance)
        #expect(!instanceViewModel.isEditingTemplate)
    }

    // MARK: willDemoteTemplate

    @Test("willDemoteTemplate is true only when editing a template whose weekdays have been cleared", arguments: [
        (startsAsTemplate: true, weekdaysAfterEdit: [Locale.Weekday](), expected: true),
        (startsAsTemplate: true, weekdaysAfterEdit: [Locale.Weekday.monday], expected: false),
        (startsAsTemplate: false, weekdaysAfterEdit: [Locale.Weekday](), expected: false),
    ])
    func willDemoteTemplate(startsAsTemplate: Bool, weekdaysAfterEdit: [Locale.Weekday], expected: Bool) {
        let item = PlanItem(
            title: "Item",
            date: .now,
            recurringWeekdays: startsAsTemplate ? [.monday] : [],
            isTemplate: startsAsTemplate
        )
        let viewModel = ItemFormViewModel(item: item)
        viewModel.recurringWeekdays = weekdaysAfterEdit
        #expect(viewModel.willDemoteTemplate == expected)
    }

    // MARK: Initializers

    @Test("The one-off initializer normalizes the date and defaults to no deadline or recurrence")
    func initForNewOneOffItem() {
        let midday = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: .now)!
        let viewModel = ItemFormViewModel(date: midday, section: .afternoon)
        #expect(viewModel.date == Calendar.current.startOfDay(for: midday))
        #expect(viewModel.daySection == .afternoon)
        #expect(!viewModel.hasDeadline)
        #expect(viewModel.recurringWeekdays.isEmpty)
    }

    @Test("The template initializer seeds the selected weekdays")
    func initForNewTemplate() {
        let viewModel = ItemFormViewModel(templateWeekdays: [.monday, .wednesday], section: .morning)
        #expect(Set(viewModel.recurringWeekdays) == [.monday, .wednesday])
        #expect(viewModel.daySection == .morning)
        #expect(!viewModel.hasDeadline)
    }

    @Test("Editing a per-day instance shows no weekdays, even though its template recurs")
    func initForInstanceHidesRecurringWeekdays() {
        let template = PlanItem(title: "Habit", date: .now, recurringWeekdays: [.monday, .tuesday], isTemplate: true)
        let instance = PlanItem(title: "Habit", date: .now)
        instance.template = template
        let viewModel = ItemFormViewModel(item: instance)
        #expect(viewModel.recurringWeekdays.isEmpty)
    }

    @Test("Editing a template shows its current weekdays")
    func initForTemplateShowsRecurringWeekdays() {
        let template = PlanItem(title: "Habit", date: .now, recurringWeekdays: [.monday, .tuesday], isTemplate: true)
        let viewModel = ItemFormViewModel(item: template)
        #expect(Set(viewModel.recurringWeekdays) == [.monday, .tuesday])
    }

    // MARK: save — guard

    @Test("save does nothing when the title is empty or whitespace-only", arguments: ["", "   "])
    func saveDoesNothingForBlankTitle(title: String) throws {
        let context = try makeContext()
        let viewModel = ItemFormViewModel(date: .now)
        viewModel.title = title
        viewModel.save(in: context)
        #expect(try fetchItems(context).isEmpty)
    }

    // MARK: save — creating new items

    @Test("save creates a new one-off item with the trimmed title and no recurrence")
    func saveCreatesNewOneOffItem() throws {
        let context = try makeContext()
        let viewModel = ItemFormViewModel(date: .now, section: .evening)
        viewModel.title = "  Buy milk  "
        viewModel.save(in: context)

        let items = try fetchItems(context)
        #expect(items.count == 1)
        let saved = items[0]
        #expect(saved.title == "Buy milk")
        #expect(saved.daySection == .evening)
        #expect(saved.deadline == nil)
        #expect(!saved.isTemplate)
    }

    @Test("save creates a new recurring template when weekdays are selected")
    func saveCreatesNewRecurringTemplate() throws {
        let context = try makeContext()
        let viewModel = ItemFormViewModel(templateWeekdays: [.monday, .friday], section: .morning)
        viewModel.title = "Team standup"
        viewModel.save(in: context)

        let items = try fetchItems(context)
        #expect(items.count == 1)
        #expect(items[0].isTemplate)
        #expect(Set(items[0].recurringWeekdays) == [.monday, .friday])
    }

    @Test("save aligns the deadline's clock time onto the item's day and clears any day section")
    func saveAlignsDeadlineAndClearsDaySection() throws {
        let context = try makeContext()
        let day = Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: .now))!
        let viewModel = ItemFormViewModel(date: day, section: .morning)
        viewModel.title = "Dentist"
        viewModel.hasDeadline = true
        viewModel.deadline = Calendar.current.date(bySettingHour: 15, minute: 45, second: 0, of: .now)!
        viewModel.save(in: context)

        let saved = try fetchItems(context)[0]
        let expectedDeadline = Calendar.current.date(bySettingHour: 15, minute: 45, second: 0, of: day)!
        #expect(saved.deadline == expectedDeadline)
        #expect(saved.daySection == nil)
    }

    @Test("save assigns the selected categories to the item")
    func saveAssignsSelectedCategories() throws {
        let context = try makeContext()
        let health = PlanCategory(name: "Health")
        context.insert(health)
        try context.save()

        let viewModel = ItemFormViewModel(date: .now)
        viewModel.title = "Run"
        viewModel.selectedCategories = [health]
        viewModel.save(in: context)

        let saved = try fetchItems(context)[0]
        #expect((saved.categories ?? []).map(\.name) == ["Health"])
    }

    // MARK: save — editing existing items

    @Test("save updates an existing one-off item's fields in place without inserting a duplicate")
    func saveUpdatesExistingOneOffItem() throws {
        let context = try makeContext()
        let existing = PlanItem(title: "Old title", notes: "old notes", date: .now)
        context.insert(existing)
        try context.save()

        let viewModel = ItemFormViewModel(item: existing)
        viewModel.title = "New title"
        viewModel.notes = "new notes"
        viewModel.isFlagged = true
        viewModel.save(in: context)

        let items = try fetchItems(context)
        #expect(items.count == 1)
        #expect(existing.title == "New title")
        #expect(existing.notes == "new notes")
        #expect(existing.isFlagged)
    }

    @Test("save on a per-day instance updates its own fields but leaves its date and template's schedule untouched")
    func saveOnInstanceDoesNotChangeScheduleOrDate() throws {
        let context = try makeContext()
        let template = PlanItem(title: "Habit", date: .now, daySection: .morning, recurringWeekdays: [.monday], isTemplate: true)
        context.insert(template)
        let instanceDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        let instance = PlanItem(title: "Habit", date: instanceDate, daySection: .morning)
        instance.template = template
        context.insert(instance)
        try context.save()

        let viewModel = ItemFormViewModel(item: instance)
        viewModel.title = "Habit (done differently today)"
        viewModel.date = Calendar.current.date(byAdding: .day, value: 5, to: Calendar.current.startOfDay(for: .now))!
        viewModel.recurringWeekdays = [.tuesday, .wednesday]
        viewModel.save(in: context)

        #expect(instance.title == "Habit (done differently today)")
        #expect(instance.date == instanceDate)
        #expect(template.recurringWeekdays == [.monday])
        #expect(template.isTemplate)
    }

    @Test("save demotes a template to a one-off item when all weekdays are cleared, severing its instances")
    func saveDemotesTemplateAndSeversInstances() throws {
        let context = try makeContext()
        let template = PlanItem(title: "Habit", date: .now, daySection: .morning, recurringWeekdays: [.monday], isTemplate: true)
        context.insert(template)
        let instance = PlanItem(title: "Habit", date: .now, daySection: .morning)
        instance.template = template
        context.insert(instance)
        try context.save()

        let viewModel = ItemFormViewModel(item: template)
        viewModel.recurringWeekdays = []
        viewModel.save(in: context)

        #expect(!template.isTemplate)
        #expect(instance.template == nil)
    }

    @Test("save promotes a one-off item to a recurring template when weekdays are added")
    func savePromotesOneOffToTemplate() throws {
        let context = try makeContext()
        let existing = PlanItem(title: "Stretch", date: .now)
        context.insert(existing)
        try context.save()

        let viewModel = ItemFormViewModel(item: existing)
        viewModel.recurringWeekdays = [.saturday, .sunday]
        viewModel.save(in: context)

        #expect(existing.isTemplate)
        #expect(Set(existing.recurringWeekdays) == [.saturday, .sunday])
    }
}
