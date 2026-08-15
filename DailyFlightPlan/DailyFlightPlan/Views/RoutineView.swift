//
//  RoutineView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct RoutineView: View {

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == true }, sort: \PlanItem.title)
    private var templates: [PlanItem]

    @Environment(\.modelContext) private var modelContext

    @State private var itemToEdit: PlanItem?
    @State private var addingWithWeekdays: Set<Locale.Weekday>?
    @State private var isPickingCustomSection = false
    @State private var pendingWeekdays: Set<Locale.Weekday>?
    @State private var sectionToDelete: (title: String, pattern: Set<Locale.Weekday>)?

    private static let everyDay: Set<Locale.Weekday> = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]
    private static let weekdays: Set<Locale.Weekday> = [
        .monday, .tuesday, .wednesday, .thursday, .friday
    ]
    private static let weekends: Set<Locale.Weekday> = [.saturday, .sunday]
    private static let presets: [Set<Locale.Weekday>] = [everyDay, weekdays, weekends]

    // Weekday ordering and display names (Sun-first)
    private static let weekdayInfo: [(Locale.Weekday, String)] = [
        (.sunday, "Sun"), (.monday, "Mon"), (.tuesday, "Tue"),
        (.wednesday, "Wed"), (.thursday, "Thu"), (.friday, "Fri"), (.saturday, "Sat")
    ]

    var body: some View {
        NavigationStack {
            List {
                routineSection(name: "Every Day", pattern: Self.everyDay, isDeletable: false)
                routineSection(name: "Weekdays", pattern: Self.weekdays, isDeletable: false)
                routineSection(name: "Weekends", pattern: Self.weekends, isDeletable: false)

                ForEach(sortedCustomGroups, id: \.key) { group in
                    routineSection(name: group.name, pattern: group.pattern, isDeletable: true)
                }
            }
            .navigationTitle("Routine")
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button {
                        isPickingCustomSection = true
                    } label: {
                        Label("Add Section", systemImage: "plus.rectangle.portrait")
                    }
                }
            }
        }
        .sheet(item: $itemToEdit) { item in
            ItemForm(item: item)
        }
        .sheet(isPresented: Binding(
            get: { addingWithWeekdays != nil },
            set: { if !$0 { addingWithWeekdays = nil } }
        )) {
            if let weekdays = addingWithWeekdays {
                ItemForm(templateWeekdays: weekdays)
            }
        }
        .sheet(isPresented: $isPickingCustomSection, onDismiss: {
            if let days = pendingWeekdays {
                pendingWeekdays = nil
                Task { @MainActor in
                    // Brief pause lets the first sheet fully dismiss before the next appears
                    try? await Task.sleep(for: .milliseconds(50))
                    addingWithWeekdays = days
                }
            }
        }) {
            let existingPatterns = Self.presets + sortedCustomGroups.map(\.pattern)
            WeekdayPickerSheet(existingPatterns: existingPatterns) { days in
                pendingWeekdays = days
                isPickingCustomSection = false
            }
        }
        .confirmationDialog(
            "Delete \"\(sectionToDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { sectionToDelete != nil },
                set: { if !$0 { sectionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete All Routines in Section", role: .destructive) {
                if let pattern = sectionToDelete?.pattern {
                    deleteSection(pattern: pattern)
                }
                sectionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sectionToDelete = nil }
        } message: {
            Text("All routines in this section will be deleted. Past completions will be kept as standalone items.")
        }
    }

    // MARK: Section builder

    @ViewBuilder
    private func routineSection(name: String, pattern: Set<Locale.Weekday>, isDeletable: Bool) -> some View {
        let sectionItems = items(for: pattern)
        Section {
            ForEach(sectionItems) { template in
                templateRow(template)
            }
            .onDelete { offsets in
                for i in offsets { deleteTemplate(sectionItems[i]) }
            }
            addButton(for: pattern)
        } header: {
            HStack {
                Text(name)
                Spacer()
                if isDeletable {
                    Button {
                        sectionToDelete = (name, pattern)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { dropped, _ in
                guard let uuidString = dropped.first else { return false }
                return reassign(uuidString: uuidString, to: pattern)
            }
        }
    }

    // MARK: Template row

    @ViewBuilder
    private func templateRow(_ template: PlanItem) -> some View {
        Button {
            itemToEdit = template
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .foregroundStyle(.primary)
                    if let section = template.daySection {
                        Text(section.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let deadline = template.deadline {
                        Text(deadline, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if template.isFlagged {
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .draggable(template.uuid.uuidString)
    }

    @ViewBuilder
    private func addButton(for pattern: Set<Locale.Weekday>) -> some View {
        Button {
            addingWithWeekdays = pattern
        } label: {
            Label("Add Routine", systemImage: "plus.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Data helpers

    private func items(for pattern: Set<Locale.Weekday>) -> [PlanItem] {
        templates.filter { Set($0.recurringWeekdays) == pattern }
    }

    private struct CustomGroup {
        let key: String
        let name: String
        let pattern: Set<Locale.Weekday>
    }

    private var sortedCustomGroups: [CustomGroup] {
        var grouped: [String: Set<Locale.Weekday>] = [:]
        for template in templates {
            let days = Set(template.recurringWeekdays)
            guard !Self.presets.contains(days) && !days.isEmpty else { continue }
            let key = weekdayKey(days)
            grouped[key] = days
        }
        return grouped.keys.sorted().map { key in
            let pattern = grouped[key]!
            return CustomGroup(key: key, name: sectionTitle(for: pattern), pattern: pattern)
        }
    }

    private func weekdayKey(_ days: Set<Locale.Weekday>) -> String {
        days.compactMap { day in Self.weekdayInfo.firstIndex(where: { $0.0 == day }) }
            .sorted()
            .map(String.init)
            .joined()
    }

    private func sectionTitle(for days: Set<Locale.Weekday>) -> String {
        Self.weekdayInfo
            .filter { days.contains($0.0) }
            .map(\.1)
            .joined(separator: " · ")
    }

    @discardableResult
    private func reassign(uuidString: String, to pattern: Set<Locale.Weekday>) -> Bool {
        guard let uuid = UUID(uuidString: uuidString),
              let template = templates.first(where: { $0.uuid == uuid }),
              Set(template.recurringWeekdays) != pattern else { return false }
        template.recurringWeekdays = Array(pattern)
        try? modelContext.save()
        return true
    }

    private func deleteSection(pattern: Set<Locale.Weekday>) {
        for template in items(for: pattern) {
            deleteTemplate(template)
        }
    }

    private func deleteTemplate(_ template: PlanItem) {
        // Sever instances so they become standalone historical records
        for instance in template.instances ?? [] {
            instance.template = nil
        }
        modelContext.delete(template)
        try? modelContext.save()
    }
}

// MARK: - Weekday picker sheet

private struct WeekdayPickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    let existingPatterns: [Set<Locale.Weekday>]
    let onConfirm: (Set<Locale.Weekday>) -> Void

    @State private var selected: Set<Locale.Weekday> = []

    private static let allWeekdays: [(Locale.Weekday, String)] = [
        (.sunday, "Su"), (.monday, "Mo"), (.tuesday, "Tu"),
        (.wednesday, "We"), (.thursday, "Th"), (.friday, "Fr"), (.saturday, "Sa")
    ]

    private var alreadyExists: Bool { existingPatterns.contains(selected) }
    private var isValid: Bool { !selected.isEmpty && !alreadyExists }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose which days this section repeats")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 8) {
                    ForEach(0..<Self.allWeekdays.count, id: \.self) { i in
                        let (weekday, abbrev) = Self.allWeekdays[i]
                        let isOn = selected.contains(weekday)
                        Button {
                            if isOn { selected.remove(weekday) } else { selected.insert(weekday) }
                        } label: {
                            Text(abbrev)
                                .font(.caption.bold())
                                .frame(width: 38, height: 38)
                                .background(
                                    isOn ? Color.accentColor : Color.secondary.opacity(0.15),
                                    in: Circle()
                                )
                                .foregroundStyle(isOn ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if alreadyExists {
                    Text("A section with these days already exists.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("New Section")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") { onConfirm(selected) }
                        .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    RoutineView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
