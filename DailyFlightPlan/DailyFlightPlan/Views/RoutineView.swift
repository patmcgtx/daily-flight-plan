//
//  RoutineView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import Flow

struct RoutineView: View {
    
    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == true }, sort: \PlanItem.title)
    private var templates: [PlanItem]
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var itemToEdit: PlanItem?
    @State private var addingWithWeekdays: Set<Locale.Weekday>?
    @State private var isPickingCustomSection = false
    @State private var pendingWeekdays: Set<Locale.Weekday>?
    @State private var sectionToDelete: (title: String, pattern: Set<Locale.Weekday>)?
    @State private var collapsedCards: Set<String> = []
    
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scheduleCard("Every Day", pattern: Self.everyDay, isDeletable: false)
                    scheduleCard("Weekdays", pattern: Self.weekdays, isDeletable: false)
                    scheduleCard("Weekends", pattern: Self.weekends, isDeletable: false)
                    
                    ForEach(sortedCustomGroups, id: \.key) { group in
                        scheduleCard(group.name, pattern: group.pattern, isDeletable: true)
                    }
                }
                .padding()
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
    
    // MARK: Schedule card
    
    @ViewBuilder
    private func scheduleCard(_ name: String, pattern: Set<Locale.Weekday>, isDeletable: Bool) -> some View {
        let segments = sortedSegments(for: pattern)
        let totalItems = items(for: pattern).count
        let isExpanded = !collapsedCards.contains(name)
        
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                Button {
                    withAnimation(.spring(duration: 0.3)) { _ = collapsedCards.insert(name) }
                } label: {
                    HStack(spacing: 12) {
                        Text(name)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            addingWithWeekdays = pattern
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                        .accessibilityLabel("Add Routine")
                        if isDeletable {
                            Button {
                                sectionToDelete = (name, pattern)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Delete Section")
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.04))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
                Divider()
                
                if segments.isEmpty {
                    Text("No routines yet.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(14)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(segments) { entry in
                            segmentGroupContent(for: entry)
                        }
                    }
                    .padding(14)
                }
            } else {
                Button {
                    withAnimation(.spring(duration: 0.3)) { _ = collapsedCards.remove(name) }
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(totalItems == 0 ? "No routines" : "\(totalItems) routine\(totalItems == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.04))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .background { RoundedRectangle(cornerRadius: 18).fill(.background) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .dropDestination(for: String.self) { dropped, _ in
            guard let uuidString = dropped.first else { return false }
            return reassign(uuidString: uuidString, to: pattern)
        }
    }
    
    // MARK: Routine pill
    
    @ViewBuilder
    private func routinePill(_ template: PlanItem) -> some View {
        Button { itemToEdit = template } label: {
            HStack(spacing: 4) {
                if template.isFlagged {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(template.title)
                    .font(.subheadline)
                if let deadline = template.deadline {
                    Text(deadline, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !template.notes.isEmpty {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { itemToEdit = template } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button("Delete", role: .destructive) { deleteTemplate(template) }
        }
        .draggable(template.uuid.uuidString)
    }
    
    // MARK: Segment group content
    
    @ViewBuilder
    private func segmentGroupContent(for entry: SegmentGroup) -> some View {
        let deadlineItems = entry.items.filter { $0.deadline != nil }
        let pillItems = entry.items.filter { $0.deadline == nil }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text(entry.segment?.displayName ?? "Open")
                    .font(.subheadline.bold())
                if let segment = entry.segment {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(segment.timeRangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !deadlineItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(deadlineItems) { template in
                        routineDeadlineRow(template)
                        if template.id != deadlineItems.last?.id {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
            }
            if !pillItems.isEmpty {
                HFlow(itemSpacing: 6, rowSpacing: 6) {
                    ForEach(pillItems) { template in
                        routinePill(template)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func routineDeadlineRow(_ template: PlanItem) -> some View {
        Button { itemToEdit = template } label: {
            HStack(spacing: 10) {
                if let deadline = template.deadline {
                    Text(deadline, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                Text(template.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    if template.isFlagged {
                        Image(systemName: "flag.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    if !template.notes.isEmpty {
                        Image(systemName: "note.text").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { itemToEdit = template } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button("Delete", role: .destructive) { deleteTemplate(template) }
        }
        .draggable(template.uuid.uuidString)
    }
    
    // MARK: Data helpers
    
    private struct SegmentGroup: Identifiable {
        let segment: DaySection?
        let items: [PlanItem]
        var id: String { segment?.rawValue ?? "open" }
    }
    
    private func sortedSegments(for pattern: Set<Locale.Weekday>) -> [SegmentGroup] {
        var grouped: [DaySection?: [PlanItem]] = [:]
        for item in items(for: pattern) {
            if let section = item.daySection {
                grouped[section, default: []].append(item)
            } else if let deadline = item.deadline, let section = DaySection.containing(deadline) {
                grouped[section, default: []].append(item)
            } else {
                grouped[nil, default: []].append(item)
            }
        }
        // Sort within each group: timed items first by time, then alphabetically
        for key in grouped.keys {
            grouped[key]?.sort { a, b in
                switch (a.deadline, b.deadline) {
                case let (.some(da), .some(db)): return da < db
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return a.title.localizedCompare(b.title) == .orderedAscending
                }
            }
        }
        // Emit in DaySection order, Open group at end
        var result = DaySection.allCases.compactMap { section -> SegmentGroup? in
            guard let items = grouped[DaySection?.some(section)], !items.isEmpty else { return nil }
            return SegmentGroup(segment: section, items: items)
        }
        if let openItems = grouped[nil], !openItems.isEmpty {
            result.append(SegmentGroup(segment: nil, items: openItems))
        }
        return result
    }
    
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
        let templatesToDelete = items(for: pattern)
        guard !templatesToDelete.isEmpty else { return }
        for template in templatesToDelete {
            deleteTemplate(template, shouldSave: false)
        }
        try? modelContext.save()
    }
    
    private func deleteTemplate(_ template: PlanItem, shouldSave: Bool = true) {
        // Sever instances so they become standalone historical records
        for instance in template.instances ?? [] {
            instance.template = nil
        }
        modelContext.delete(template)
        if shouldSave {
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
    
}

#if DEBUG

#Preview {
    RoutineView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#endif
