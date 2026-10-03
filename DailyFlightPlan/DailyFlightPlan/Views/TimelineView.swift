//
//  TimelineView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct TimelineView: View {

    /// Set when embedded inline as a tab; nil means sheet mode (uses environment dismiss).
    var onDismiss: (() -> Void)? = nil

    @Binding var searchText: String

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false }, sort: \PlanItem.date)
    private var allItems: [PlanItem]

    @Environment(\.dismiss) private var envDismiss
    @Environment(\.categorySelectionService) private var categorySelectionService
    @Environment(\.modelContext) private var modelContext

    @State private var itemToEdit: PlanItem? = nil
    @State private var addItemRequest: AddItemRequest? = nil

    private struct AddItemRequest: Identifiable {
        let date: Date
        let section: DaySection?
        var id: String { "\(date)|\(section?.rawValue ?? "open")" }
    }

    private func handleDismiss() {
        if let onDismiss { onDismiss() } else { envDismiss() }
    }

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue) private var showFlaggedOnly: Bool = false
    @AppStorage(AppStorageKeys.showMissedOnly.rawValue) private var showMissedOnly: Bool = false
    @AppStorage(AppStorageKeys.showCompletedOnly.rawValue) private var showCompletedOnly: Bool = false

    /// How many days of history/future are currently loaded, in each direction from today.
    /// Grows in weekly increments as the user scrolls toward either edge.
    @State private var pastDaysWindow: Int = 7
    @State private var futureDaysWindow: Int = 7

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    private var minLoadedDate: Date {
        calendar.date(byAdding: .day, value: -pastDaysWindow, to: today) ?? today
    }

    private var maxLoadedDate: Date {
        calendar.date(byAdding: .day, value: futureDaysWindow, to: today) ?? today
    }

    private var filteredItems: [PlanItem] {
        let windowed = allItems.filter { item in
            let day = calendar.startOfDay(for: item.date)
            guard day >= minLoadedDate && day <= maxLoadedDate else { return false }
            // Future dates never show routine instances — routines could still change before then.
            return day <= today || item.template == nil
        }
        let filtered = windowed.matchingTimelineStatusFilters(
            showFlaggedOnly: showFlaggedOnly, showCompletedOnly: showCompletedOnly,
            showMissedOnly: showMissedOnly, isMissed: isMissed
        )
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    /// Today and every loaded future day always get a section — even empty ones — so each has its
    /// "Add item" affordance. Past days stay sparse: a section only appears if it actually has
    /// items, so an empty history window doesn't turn into a wall of "Nothing planned" rows.
    private var groupedByDate: [(date: Date, items: [PlanItem])] {
        var dict = Dictionary(grouping: filteredItems) { calendar.startOfDay(for: $0.date) }
        for offset in 0...futureDaysWindow {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if dict[date] == nil { dict[date] = [] }
        }
        return dict.keys.sorted().map { date in (date: date, items: dict[date]!) }
    }

    /// Searches by title and notes across *every* loaded-or-not date — unlike the grouped list,
    /// this deliberately ignores `minLoadedDate`/`maxLoadedDate` since search is meant to reach
    /// the whole history/future, not just the currently pre-cached window. Runs as a fresh
    /// `FetchDescriptor` against the store (with the text match pushed down via
    /// `localizedStandardContains`, not `allItems.filter` in memory) so search performance and
    /// memory use don't scale with total item count as the database grows over time — only
    /// `allItems` (the day-windowed browsing view) still holds everything matching `isTemplate ==
    /// false` in memory; see the implementation plan for that remaining scaling concern.
    private var searchResults: [PlanItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        // Same future-instance guard as `filteredItems` (line 60), expressed as `date < tomorrow`
        // since #Predicate can't call `calendar.startOfDay` — a plain Date comparison computed
        // outside the predicate. Without this, a materialized recurring instance dated in the
        // future (possible via multi-device clock/timezone skew during CloudKit sync) would be
        // hidden while browsing but resurface here if it happened to match the search text.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let predicate = #Predicate<PlanItem> { item in
            item.isTemplate == false
            && (item.date < tomorrow || item.template == nil)
            && (item.title.localizedStandardContains(query) || item.notes.localizedStandardContains(query))
        }
        let descriptor = FetchDescriptor<PlanItem>(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        let matched = (try? modelContext.fetch(descriptor)) ?? []
        let filtered = matched.matchingTimelineStatusFilters(
            showFlaggedOnly: showFlaggedOnly, showCompletedOnly: showCompletedOnly,
            showMissedOnly: showMissedOnly, isMissed: isMissed
        )
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    /// Pending item whose deadline, day-section window, or entire day has already passed.
    private func isMissed(_ item: PlanItem) -> Bool {
        guard item.status == .pending else { return false }
        let day = calendar.startOfDay(for: item.date)
        guard day <= today else { return false }
        if let deadline = item.deadline { return deadline < Date.now }
        if day < today { return true }
        guard let section = item.daySection,
              let sectionEnd = calendar.date(
                  bySettingHour: section.endHour, minute: 59, second: 59, of: Date.now
              ) else { return false }
        return sectionEnd < Date.now
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if searchText.isEmpty {
                        ForEach(groupedByDate, id: \.date) { group in
                            Section {
                                let canAddItems = group.date >= today
                                if group.items.isEmpty && !canAddItems {
                                    Text("Nothing planned")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    ForEach(segmentedGroups(for: group.items, includeEmpty: canAddItems)) { segment in
                                        segmentHeader(
                                            for: segment.section,
                                            onAdd: canAddItems ? { addItemRequest = AddItemRequest(date: group.date, section: segment.section) } : nil
                                        )
                                        ForEach(segment.items) { item in
                                            TimelineItemRow(item: item) {
                                                itemToEdit = item
                                            }
                                        }
                                    }
                                }
                            } header: {
                                dateHeader(for: group.date)
                            }
                            .id(group.date)
                            .onAppear {
                                // Guard against a single visible group matching both first and last —
                                // that's an initial-render artifact, not a real scroll-to-edge event.
                                guard groupedByDate.count > 1 else { return }
                                if group.date == groupedByDate.first?.date {
                                    pastDaysWindow += 7
                                }
                                if group.date == groupedByDate.last?.date {
                                    futureDaysWindow += 7
                                }
                            }
                        }
                    } else if searchResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(searchResults) { item in
                            TimelineItemRow(item: item, showDate: true) {
                                itemToEdit = item
                            }
                        }
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #else
                .listStyle(.insetGrouped)
                #endif
                .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
                .sheet(item: $addItemRequest) { request in
                    ItemForm(date: request.date, section: request.section)
                }
                .navigationTitle("Timeline")
                .inlineNavigationTitle()
                .toolbar {
                    if onDismiss == nil {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { handleDismiss() }
                        }
                    }
                    ToolbarItem(placement: .trailingBar) {
                        FilterToolbarButton(activeTab: .timeline, searchText: $searchText)
                    }
                }
                .onAppear {
                    proxy.scrollTo(today, anchor: .center)
                }
            }
        }
    }

    // MARK: Date header

    @ViewBuilder
    private func dateHeader(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isPast = date < today
        HStack {
            if isToday {
                Text("Today")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(isPast ? .secondary : .primary)
            }
            Spacer()
        }
    }

    // MARK: Segment grouping within a day

    private struct SegmentGroup: Identifiable {
        let section: DaySection?
        let items: [PlanItem]
        var id: String { section?.rawValue ?? "open" }
    }

    /// Groups a day's items into time-of-day segments for readability — deadline items fall into
    /// the segment containing their clock time; segment-assigned items use their explicit segment;
    /// everything else lands in a trailing "Open" group. Empty segments are omitted for past days
    /// (a historical log isn't something to plan against), but included for today/future days so
    /// every segment gets an "Add item" affordance even before it has anything in it.
    private func segmentedGroups(for items: [PlanItem], includeEmpty: Bool) -> [SegmentGroup] {
        var grouped: [DaySection?: [PlanItem]] = [:]
        for item in items {
            if let section = item.daySection {
                grouped[section, default: []].append(item)
            } else if let deadline = item.deadline, let section = DaySection.containing(deadline) {
                grouped[section, default: []].append(item)
            } else {
                grouped[nil, default: []].append(item)
            }
        }
        for key in grouped.keys {
            grouped[key]?.sort { a, b in
                switch (a.deadline, b.deadline) {
                case let (.some(da), .some(db)): return da < db
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return a.title < b.title
                }
            }
        }
        var result = DaySection.allCases.compactMap { section -> SegmentGroup? in
            let items = grouped[section] ?? []
            guard includeEmpty || !items.isEmpty else { return nil }
            return SegmentGroup(section: section, items: items)
        }
        let openItems = grouped[nil] ?? []
        if includeEmpty || !openItems.isEmpty {
            result.append(SegmentGroup(section: nil, items: openItems))
        }
        return result
    }

    private func segmentHeader(for section: DaySection?, onAdd: (() -> Void)?) -> some View {
        HStack {
            Text(section?.displayName ?? "Open")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Row

private struct TimelineItemRow: View {

    let item: PlanItem
    var showDate: Bool = false
    let onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 10) {
            checkboxButton
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .strikethrough(item.status == .completed || item.status == .canceled)
                        .foregroundStyle(item.status == .canceled ? .secondary : .primary)
                        .lineLimit(1)
                    if item.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    if !item.notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                subtitle
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
        }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
    }

    @ViewBuilder
    private var checkboxButton: some View {
        Button {
            guard item.status != .canceled else { return }
            withAnimation(.spring(duration: 0.2)) {
                item.status = item.status == .completed ? .pending : .completed
                try? modelContext.save()
            }
        } label: {
            switch item.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            case .canceled:
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            case .pending:
                Image(systemName: "circle")
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var subtitle: some View {
        if showDate || item.deadline != nil {
            HStack(spacing: 4) {
                if showDate {
                    Text(item.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let deadline = item.deadline {
                    Text(deadline, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#if DEBUG

#Preview {
    @Previewable @State var searchText = ""
    TimelineView(searchText: $searchText)
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#endif 
