//
//  TimelineView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct TimelineView: View {

    /// Set when embedded inline as a tab; nil means sheet mode (uses environment dismiss).
    var onDismiss: (() -> Void)? = nil

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false }, sort: \PlanItem.date)
    private var allItems: [PlanItem]
    @Query(sort: \PlanCategory.name) private var allCategories: [PlanCategory]

    @Environment(\.dismiss) private var envDismiss
    @Environment(\.categorySelectionService) private var categorySelectionService
    @Environment(\.modelContext) private var modelContext

    @State private var itemToEdit: PlanItem? = nil

    private func handleDismiss() {
        if let onDismiss { onDismiss() } else { envDismiss() }
    }

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue) private var showFlaggedOnly: Bool = false
    @AppStorage(AppStorageKeys.showMissedOnly.rawValue) private var showMissedOnly: Bool = false

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
        let filtered = allItems.filter { item in
            let day = calendar.startOfDay(for: item.date)
            guard day >= minLoadedDate && day <= maxLoadedDate else { return false }
            // Future dates never show routine instances — routines could still change before then.
            guard day <= today || item.template == nil else { return false }
            guard !showFlaggedOnly || item.isFlagged else { return false }
            guard !showMissedOnly || isMissed(item) else { return false }
            return true
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    private var groupedByDate: [(date: Date, items: [PlanItem])] {
        var dict = Dictionary(grouping: filteredItems) { calendar.startOfDay(for: $0.date) }
        if dict[today] == nil { dict[today] = [] }
        return dict.keys.sorted().map { date in (date: date, items: dict[date]!) }
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
                    ForEach(groupedByDate, id: \.date) { group in
                        Section {
                            if group.items.isEmpty {
                                Text("Nothing planned")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            } else {
                                ForEach(segmentedGroups(for: group.items)) { segment in
                                    segmentHeader(for: segment.section)
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
                            if group.date == groupedByDate.first?.date {
                                pastDaysWindow += 7
                            }
                            if group.date == groupedByDate.last?.date {
                                futureDaysWindow += 7
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
                .navigationTitle("Nav Log")
                .inlineNavigationTitle()
                .toolbar {
                    if onDismiss == nil {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { handleDismiss() }
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    filterBar
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

    // MARK: Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterToggle("Flagged", icon: "flag.fill", isActive: showFlaggedOnly) {
                    showFlaggedOnly.toggle()
                }
                filterToggle("Missed", icon: "clock.badge.exclamationmark", isActive: showMissedOnly) {
                    showMissedOnly.toggle()
                }
                if !allCategories.isEmpty {
                    Divider().frame(height: 20)
                    ForEach(allCategories) { category in
                        CategoryCapsule(category: category)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func filterToggle(
        _ title: String, icon: String, isActive: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .background {
            if isActive {
                Capsule().fill(Color.accentColor)
            } else {
                Capsule().fill(.regularMaterial)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Segment grouping within a day

    private struct SegmentGroup: Identifiable {
        let section: DaySection?
        let items: [PlanItem]
        var id: String { section?.rawValue ?? "open" }
    }

    /// Groups a day's items into time-of-day segments for readability — deadline items fall into
    /// the segment containing their clock time; segment-assigned items use their explicit segment;
    /// everything else lands in a trailing "Open" group. Empty segments are omitted (unlike the Day
    /// view's persistent cards, this is a historical/scheduled log, not something to plan against).
    private func segmentedGroups(for items: [PlanItem]) -> [SegmentGroup] {
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
            guard let items = grouped[section], !items.isEmpty else { return nil }
            return SegmentGroup(section: section, items: items)
        }
        if let openItems = grouped[nil], !openItems.isEmpty {
            result.append(SegmentGroup(section: nil, items: openItems))
        }
        return result
    }

    private func segmentHeader(for section: DaySection?) -> some View {
        Text(section?.displayName ?? "Open")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
            .listRowSeparator(.hidden)
    }
}

// MARK: - Row

private struct TimelineItemRow: View {

    let item: PlanItem
    let onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 10) {
            checkboxButton
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.status == .completed || item.status == .canceled)
                    .foregroundStyle(item.status == .canceled ? .secondary : .primary)
                    .lineLimit(1)
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
        if let deadline = item.deadline {
            Text(deadline, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let section = item.daySection {
            Text(section.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
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
