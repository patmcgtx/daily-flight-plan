//
//  ItemForm.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct ItemForm: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlanCategory.name) private var allCategories: [PlanCategory]

    @State private var viewModel: ItemFormViewModel
    private let isCreate: Bool

    init(date: Date) {
        isCreate = true
        _viewModel = State(initialValue: ItemFormViewModel(date: date))
    }

    init(item: PlanItem) {
        isCreate = false
        _viewModel = State(initialValue: ItemFormViewModel(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                titleAndNotesSection
                detailsSection
                scheduleSection
                recurringSection
                if !allCategories.isEmpty {
                    categoriesSection
                }
            }
            .navigationTitle(isCreate ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(in: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var titleAndNotesSection: some View {
        Section {
            TextField("Title", text: Bindable(viewModel).title)
            TextField("Notes", text: Bindable(viewModel).notes, axis: .vertical)
                .lineLimit(3...)
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            DatePicker("Date", selection: Bindable(viewModel).date, displayedComponents: .date)
            Toggle(isOn: Bindable(viewModel).isFlagged) {
                Label("Flagged", systemImage: "flag.fill")
            }
            .tint(.red)
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Specific Time", isOn: Bindable(viewModel).hasDeadline)
            if viewModel.hasDeadline {
                DatePicker("Time", selection: Bindable(viewModel).deadline, displayedComponents: .hourAndMinute)
            } else {
                Picker("Section", selection: Bindable(viewModel).daySection) {
                    Text("Open").tag(Optional<DaySection>.none)
                    ForEach(DaySection.allCases) { section in
                        Text(section.displayName).tag(Optional(section))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recurringSection: some View {
        Section("Recurring") {
            Text("Make it a routine")
            weekdayPicker
        }
    }

    @ViewBuilder
    private var categoriesSection: some View {
        Section("Categories") {
            ForEach(allCategories) { category in
                categoryRow(for: category)
            }
        }
    }

    @ViewBuilder
    private func categoryRow(for category: PlanCategory) -> some View {
        let isSelected = viewModel.selectedCategories.contains {
            $0.persistentModelID == category.persistentModelID
        }
        Button {
            if isSelected {
                viewModel.selectedCategories.removeAll {
                    $0.persistentModelID == category.persistentModelID
                }
            } else {
                viewModel.selectedCategories.append(category)
            }
        } label: {
            HStack {
                Text(category.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    // MARK: Weekday picker

    private static let weekdays: [(Locale.Weekday, String)] = [
        (.sunday, "Su"), (.monday, "M"), (.tuesday, "T"),
        (.wednesday, "W"), (.thursday, "Th"), (.friday, "F"), (.saturday, "Sa")
    ]

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.weekdays.count, id: \.self) { i in
                let (weekday, label) = Self.weekdays[i]
                let isOn = viewModel.recurringWeekdays.contains(weekday)
                Button {
                    if isOn {
                        viewModel.recurringWeekdays.removeAll { $0 == weekday }
                    } else {
                        viewModel.recurringWeekdays.append(weekday)
                    }
                } label: {
                    Text(label)
                        .font(.caption.bold())
                        .frame(width: 36, height: 36)
                        .background(
                            isOn ? Color.accentColor : Color.secondary.opacity(0.15),
                            in: Circle()
                        )
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

#Preview("Create") {
    ItemForm(date: .now)
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#Preview("Edit") {
    let item = PlanItem(
        title: "Team standup",
        notes: "Check in with the team",
        isFlagged: true,
        deadline: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: .now),
        recurringWeekdays: [.monday, .wednesday, .friday]
    )
    ItemForm(item: item)
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
