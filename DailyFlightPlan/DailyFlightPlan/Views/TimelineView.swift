//
//  TimelineView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct TimelineView: View {

    let onSelectDate: (Date) -> Void
    /// Set when embedded inline as a tab; nil means sheet mode (uses environment dismiss).
    var onDismiss: (() -> Void)? = nil

    @Query(sort: \PlanItem.date) private var allItems: [PlanItem]
    @Query(sort: \PlanCategory.name) private var allCategories: [PlanCategory]

    @Environment(\.dismiss) private var envDismiss
    @Environment(\.categorySelectionService) private var categorySelectionService

    private func handleDismiss() {
        if let onDismiss { onDismiss() } else { envDismiss() }
    }

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue) private var showFlaggedOnly: Bool = false
    @AppStorage(AppStorageKeys.showCompleted.rawValue) private var showCompleted: Bool = false

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    private var filteredItems: [PlanItem] {
        let filtered = allItems.filter {
            (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    private var groupedByDate: [(date: Date, items: [PlanItem])] {
        var dict = Dictionary(grouping: filteredItems) { calendar.startOfDay(for: $0.date) }
        if dict[today] == nil { dict[today] = [] }
        return dict.keys.sorted().map { date in (date: date, items: dict[date]!) }
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
                                ForEach(sortedItems(group.items)) { item in
                                    TimelineItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onSelectDate(group.date)
                                            handleDismiss()
                                        }
                                }
                            }
                        } header: {
                            dateHeader(for: group.date)
                        }
                        .id(group.date)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Timeline")
                .navigationBarTitleDisplayMode(.inline)
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
        Button {
            onSelectDate(date)
            handleDismiss()
        } label: {
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
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterToggle("Flagged", icon: "flag.fill", isActive: showFlaggedOnly) {
                    showFlaggedOnly.toggle()
                }
                filterToggle("Done", icon: "checkmark", isActive: showCompleted) {
                    showCompleted.toggle()
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

    // MARK: Item sorting within a day

    private func sortedItems(_ items: [PlanItem]) -> [PlanItem] {
        items.sorted { a, b in
            let aRank = sortRank(a)
            let bRank = sortRank(b)
            if aRank != bRank { return aRank < bRank }
            // Within deadline group, sort by time
            if let da = a.deadline, let db = b.deadline { return da < db }
            // Within section group, sort by section order
            if let sa = a.daySection, let sb = b.daySection {
                let ai = DaySection.allCases.firstIndex(of: sa) ?? 0
                let bi = DaySection.allCases.firstIndex(of: sb) ?? 0
                return ai < bi
            }
            return a.title < b.title
        }
    }

    private func sortRank(_ item: PlanItem) -> Int {
        if item.deadline != nil { return 0 }
        if item.daySection != nil { return 1 }
        return 2
    }
}

// MARK: - Row

private struct TimelineItemRow: View {

    let item: PlanItem

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.status == .completed || item.status == .canceled)
                    .foregroundStyle(item.status == .canceled ? .secondary : .primary)
                    .lineLimit(1)
                subtitle
            }
        }
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

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .canceled:
            Image(systemName: "xmark.circle")
                .foregroundStyle(.secondary)
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TimelineView(onSelectDate: { _ in })
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
