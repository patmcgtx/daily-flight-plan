//
//  RoutineView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import Flow
import FoundationModels

struct RoutineView: View {

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == true }, sort: \PlanItem.title)
    private var templates: [PlanItem]

    @Environment(\.modelContext) private var modelContext

    @State private var itemToEdit: PlanItem?
    @State private var addingRoutine: RoutineAddRequest?
    @State private var isPickingCustomSection = false
    @State private var pendingWeekdays: Set<Locale.Weekday>?
    @State private var sectionToDelete: (title: String, pattern: Set<Locale.Weekday>)?
    @State private var collapsedCards: Set<String> = []
    @State private var collapsedSegments: Set<String> = []
    @State private var dropTargetedSegmentKey: String? = nil
    @State private var segmentSummaries: [String: String] = [:]
    @State private var loadingSummarySegments: Set<String> = []
    @State private var summaryTasks: [String: Task<Void, Never>] = [:]
    
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
            get: { addingRoutine != nil },
            set: { if !$0 { addingRoutine = nil } }
        )) {
            if let request = addingRoutine {
                ItemForm(templateWeekdays: request.weekdays, section: request.section)
            }
        }
        .sheet(isPresented: $isPickingCustomSection, onDismiss: {
            if let days = pendingWeekdays {
                pendingWeekdays = nil
                Task { @MainActor in
                    // Brief pause lets the first sheet fully dismiss before the next appears
                    try? await Task.sleep(for: .milliseconds(50))
                    addingRoutine = RoutineAddRequest(weekdays: days, section: nil)
                }
            }
        }) {
            let existingPatterns = Self.presets + sortedCustomGroups.map(\.pattern)
            WeekdayPickerSheet(existingPatterns: existingPatterns) { days in
                pendingWeekdays = days
                isPickingCustomSection = false
            }
        }
        .onChange(of: templatesSignature) { _, _ in
            clearAllSegmentSummaries()
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
                            addingRoutine = RoutineAddRequest(weekdays: pattern, section: nil)
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

                // Always render segment cards, even when totalItems == 0 — each segment shows
                // its own "No routines yet." state, and (unlike a single placeholder Text) still
                // exposes a per-segment drop target so a drag can land directly in a segment on
                // an otherwise-empty schedule card.
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(segments) { entry in
                        segmentCard(for: entry, cardName: name, pattern: pattern)
                    }
                }
                .padding(12)
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
    
    // MARK: Segment card

    /// A collapsible card for one day-section's routines within a schedule card,
    /// styled to match the per-section cards on the Day view so "segment" reads
    /// the same across both screens.
    private struct RoutineAddRequest {
        let weekdays: Set<Locale.Weekday>
        let section: DaySection?
    }

    private func segmentKey(cardName: String, entry: SegmentGroup) -> String {
        "\(cardName)|\(entry.id)"
    }

    @ViewBuilder
    private func segmentCard(for entry: SegmentGroup, cardName: String, pattern: Set<Locale.Weekday>) -> some View {
        let deadlineItems = entry.items.filter { $0.deadline != nil }
        let pillItems = entry.items.filter { $0.deadline == nil }
        let total = entry.items.count
        let key = segmentKey(cardName: cardName, entry: entry)
        let isExpanded = !collapsedSegments.contains(key)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if isExpanded {
                        collapsedSegments.insert(key)
                    } else {
                        collapsedSegments.remove(key)
                    }
                }
            } label: {
                segmentHeader(entry: entry, total: total, isExpanded: isExpanded, key: key)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onAppear {
                if total > 0 {
                    generateSegmentSummaryIfNeeded(key: key, items: entry.items)
                }
            }

            if isExpanded {
                Divider()

                Button {
                    addingRoutine = RoutineAddRequest(weekdays: pattern, section: entry.segment)
                } label: {
                    Label("Add item", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                }
                .buttonStyle(.plain)

                if total == 0 {
                    Text("No routines yet.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        if !deadlineItems.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(deadlineItems) { template in
                                    routineDeadlineRow(template)
                                    if template.id != deadlineItems.last?.id {
                                        Divider().padding(.leading, 58)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        if !pillItems.isEmpty {
                            HFlow(itemSpacing: 6, rowSpacing: 6) {
                                ForEach(pillItems) { template in
                                    routinePill(template)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, deadlineItems.isEmpty ? 10 : 6)
                            .padding(.bottom, 10)
                        } else {
                            Spacer(minLength: 6)
                        }
                    }
                }
            }
        }
        .background { RoundedRectangle(cornerRadius: 14).fill(.background) }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator, lineWidth: 0.5)
        }
        .overlay {
            if dropTargetedSegmentKey == key {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .dropDestination(for: String.self) { dropped, _ in
            guard let uuidString = dropped.first else { return false }
            return reassignSegment(uuidString: uuidString, to: entry.segment, pattern: pattern)
        } isTargeted: { targeted in
            dropTargetedSegmentKey = targeted ? key : nil
        }
        .animation(.easeInOut(duration: 0.15), value: dropTargetedSegmentKey == key)
    }

    private func segmentHeader(entry: SegmentGroup, total: Int, isExpanded: Bool, key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(entry.segment?.displayName ?? "Open")
                        .font(isExpanded ? .headline : .subheadline.bold())
                    if let segment = entry.segment {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(segment.timeRangeLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !isExpanded {
                    if total == 0 {
                        Text("No routines")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let summary = segmentSummaries[key] {
                        Text(summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else if loadingSummarySegments.contains(key) {
                        loadingDotsView
                    } else {
                        Text(quickSummary(for: entry))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if total > 0 {
                Text("\(total)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var loadingDotsView: some View {
        Text("···")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .phaseAnimator([1.0, 0.3]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
    }

    /// A deterministic, always-available preview of a segment's routines — shown until (or instead
    /// of, when the on-device model is unavailable e.g. in Simulator) the AI summary arrives.
    private func quickSummary(for entry: SegmentGroup) -> String {
        let deadlineItems = entry.items
            .filter { $0.deadline != nil }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
        let pillItems = entry.items.filter { $0.deadline == nil }

        var parts: [String] = []
        for item in deadlineItems where parts.count < 3 {
            if let dl = item.deadline {
                parts.append("\(item.title) \(dl.formatted(.dateTime.hour().minute()))")
            }
        }
        for item in pillItems where parts.count < 3 {
            parts.append(item.title)
        }

        var summary = parts.joined(separator: " · ")
        let remaining = entry.items.count - parts.count
        if remaining > 0 {
            summary += " +\(remaining) more"
        }
        return summary
    }

    // MARK: AI segment summaries

    /// A signature over all templates that changes whenever titles, sections, deadlines,
    /// or weekday patterns change — used to invalidate cached summaries reactively.
    private var templatesSignature: String {
        templates.map { item in
            "\(item.uuid)|\(item.title)|\(item.daySection?.rawValue ?? "")|\(item.deadline?.timeIntervalSinceReferenceDate ?? -1)|\(item.recurringWeekdays.map(\.rawValue).sorted())"
        }.joined(separator: ",")
    }

    private func clearAllSegmentSummaries() {
        summaryTasks.values.forEach { $0.cancel() }
        summaryTasks = [:]
        segmentSummaries = [:]
        loadingSummarySegments = []
    }

    /// Generate a one-line AI summary for a collapsed segment. Skips if already cached or in-flight.
    private func generateSegmentSummaryIfNeeded(key: String, items: [PlanItem]) {
        guard segmentSummaries[key] == nil, summaryTasks[key] == nil else { return }
        guard !items.isEmpty else { return }
        guard SystemLanguageModel.default.availability == .available else { return }

        loadingSummarySegments.insert(key)
        summaryTasks[key] = Task { @MainActor in
            defer {
                summaryTasks[key] = nil
                loadingSummarySegments.remove(key)
            }

            let session = LanguageModelSession(
                instructions: "Summarize listed routine items in under 10 words. Use very short phrases joined by · (middle dot). Be factual and concise. Output a single line only — no newlines, no bullet points, no lists."
            )

            let deadlineItems = items
                .filter { $0.deadline != nil }
                .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
            var parts = deadlineItems.prefix(6).map { item in
                "\(item.title) at \(item.deadline!.formatted(.dateTime.hour().minute()))"
            }

            let pillItems = items.filter { $0.deadline == nil }
            for item in pillItems.prefix(6) {
                parts.append(item.title)
            }

            let prompt = parts.joined(separator: "; ")
            if let response = try? await session.respond(to: prompt) {
                segmentSummaries[key] = response.content
                    .components(separatedBy: .newlines)
                    .joined(separator: " · ")
                    .trimmingCharacters(in: .whitespaces)
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
        // Emit every DaySection in order (even empty ones, so each still gets its own
        // card with an "Add item" button); Open group only appears when it has items.
        var result = DaySection.allCases.map { section in
            SegmentGroup(segment: section, items: grouped[DaySection?.some(section)] ?? [])
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

    /// Drops onto a specific day-segment card. Handles both same-card moves (just changes
    /// `daySection`) and cross-card drags landing directly on a segment (changes the weekday
    /// pattern too, in one motion) — the segment card sits in front of the schedule card's own
    /// drop target, so this is the only handler that fires when the drop lands inside a segment.
    @discardableResult
    private func reassignSegment(uuidString: String, to segment: DaySection?, pattern: Set<Locale.Weekday>) -> Bool {
        guard let uuid = UUID(uuidString: uuidString),
              let template = templates.first(where: { $0.uuid == uuid }) else { return false }
        let patternChanged = Set(template.recurringWeekdays) != pattern
        let segmentChanged = template.daySection != segment
        guard patternChanged || segmentChanged else { return false }
        withAnimation(.spring(duration: 0.3)) {
            template.recurringWeekdays = Array(pattern)
            template.daySection = segment
            template.deadline = nil
        }
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
