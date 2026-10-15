//
//  TimelineView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct TimelineView: View {

    /// Set when embedded inline as a tab; nil means sheet mode (uses environment dismiss).
    var onDismiss: (() -> Void)? = nil

    /// Timeline-only search (not part of the shared `FilterSheetView`) — a minimal field toggled
    /// by its own toolbar button, filtering this view in real time as you type.
    @State private var searchText: String = ""
    @State private var isShowingSearch = false
    @FocusState private var isSearchFieldFocused: Bool

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false }, sort: \PlanItem.date)
    private var allItems: [PlanItem]

    @Environment(\.dismiss) private var envDismiss
    @Environment(\.categorySelectionService) private var categorySelectionService
    @Environment(\.modelContext) private var modelContext

    @State private var itemToEdit: PlanItem? = nil
    @State private var addItemRequest: AddItemRequest? = nil
    @State private var viewModel = TimelineViewModel()

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

    private let calendar = Calendar.current
    private var today: Date { viewModel.today }

    /// `searchText` with whitespace trimmed — matches `matchingSearchText(_:)`'s own trimming
    /// (used by Day/Routine), so whitespace-only input is treated as "no query" everywhere, not
    /// just where that shared extension is called directly. Without this, entering only spaces
    /// would leave Day/Routine unfiltered while Timeline switched to an empty search-results
    /// screen and disabled "Go to Today".
    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredItems: [PlanItem] {
        viewModel.filteredItems(
            from: allItems,
            showFlaggedOnly: showFlaggedOnly, showCompletedOnly: showCompletedOnly,
            showMissedOnly: showMissedOnly, categorySelectionService: categorySelectionService
        )
    }

    private var groupedByDate: [(date: Date, items: [PlanItem])] {
        viewModel.groupedByDate(filteredItems)
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
        let query = trimmedSearchText
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
            showMissedOnly: showMissedOnly, isMissed: viewModel.isMissed
        )
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                // Computed once per render — `groupedByDate` re-filters/re-groups `allItems` on
                // every access since Swift computed properties aren't memoized, and this was
                // being read up to 4x per visible row (ForEach plus .count/.first/.last below).
                let groups = trimmedSearchText.isEmpty ? groupedByDate : []
                List {
                    if trimmedSearchText.isEmpty {
                        ForEach(groups, id: \.date) { group in
                            Section {
                                let canAddItems = group.date >= today
                                if group.items.isEmpty && !canAddItems {
                                    Text("Nothing planned")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    ForEach(viewModel.segmentedGroups(for: group.items, includeEmpty: canAddItems)) { segment in
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
                                guard groups.count > 1 else { return }
                                if group.date == groups.first?.date {
                                    viewModel.pastDaysWindow += 7
                                }
                                if group.date == groups.last?.date {
                                    viewModel.futureDaysWindow += 7
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
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .top) {
                    if isShowingSearch {
                        InlineSearchField(text: $searchText, isFocused: $isSearchFieldFocused)
                    }
                }
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
                        Button {
                            withAnimation { proxy.scrollTo(today, anchor: .center) }
                        } label: {
                            Image(systemName: "scope")
                        }
                        .disabled(!trimmedSearchText.isEmpty)
                        .accessibilityLabel("Go to Today")
                    }
                    ToolbarItem(placement: .trailingBar) {
                        SearchToggleButton(
                            isShowingSearch: $isShowingSearch, searchText: $searchText,
                            isFocused: $isSearchFieldFocused
                        )
                    }
                    ToolbarItem(placement: .trailingBar) {
                        FilterToolbarButton(activeTab: .timeline)
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
                Circle().fill(.red).frame(width: 6, height: 6)
                Text("TODAY")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
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

    // MARK: Segment header

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
    TimelineView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#endif 
