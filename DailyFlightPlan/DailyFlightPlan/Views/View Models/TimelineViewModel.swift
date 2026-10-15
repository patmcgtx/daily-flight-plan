//
//  TimelineViewModel.swift
//  DailyFlightPlan
//
import Foundation

/// Shared day-windowing, filtering, and grouping logic for every Timeline-style list (the
/// original Timeline tab and the Nav Log tab). Holds no SwiftData/environment dependency of its
/// own — callers pass in the already-fetched items and read-only service references — so it
/// stays trivially previewable and testable.
@Observable @MainActor
final class TimelineViewModel {

    /// How many days of history/future are currently loaded, in each direction from today.
    /// Grows in weekly increments as the user scrolls toward either edge.
    var pastDaysWindow: Int = 7
    var futureDaysWindow: Int = 7

    private let calendar = Calendar.current

    var today: Date { calendar.startOfDay(for: .now) }

    private var minLoadedDate: Date {
        calendar.date(byAdding: .day, value: -pastDaysWindow, to: today) ?? today
    }

    private var maxLoadedDate: Date {
        calendar.date(byAdding: .day, value: futureDaysWindow, to: today) ?? today
    }

    /// Pending item whose deadline, day-section window, or entire day has already passed.
    func isMissed(_ item: PlanItem) -> Bool {
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

    /// Applies only the day-load window and the future-recurring-instance guard — no status or
    /// category filtering, for views (like Nav Log) that want every item as a complete record.
    func loadedItems(from allItems: [PlanItem]) -> [PlanItem] {
        allItems.filter { item in
            let day = calendar.startOfDay(for: item.date)
            guard day >= minLoadedDate && day <= maxLoadedDate else { return false }
            // Future dates never show routine instances — routines could still change before then.
            return day <= today || item.template == nil
        }
    }

    /// Applies the day-load window, the future-recurring-instance guard, the Timeline status
    /// filters, and category filtering — the full pipeline used by the original Timeline tab.
    func filteredItems(
        from allItems: [PlanItem],
        showFlaggedOnly: Bool, showCompletedOnly: Bool, showMissedOnly: Bool,
        categorySelectionService: CategorySelectionService?
    ) -> [PlanItem] {
        let filtered = loadedItems(from: allItems).matchingTimelineStatusFilters(
            showFlaggedOnly: showFlaggedOnly, showCompletedOnly: showCompletedOnly,
            showMissedOnly: showMissedOnly, isMissed: isMissed
        )
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    /// Today and every loaded future day always get a group — even empty ones — so each has its
    /// "Add item" affordance in views that offer one. Past days stay sparse: a group only appears
    /// if it actually has items, so an empty history window doesn't turn into a wall of empty days.
    func groupedByDate(_ filteredItems: [PlanItem]) -> [(date: Date, items: [PlanItem])] {
        var dict = Dictionary(grouping: filteredItems) { calendar.startOfDay(for: $0.date) }
        for offset in 0...futureDaysWindow {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if dict[date] == nil { dict[date] = [] }
        }
        return dict.keys.sorted().map { date in (date: date, items: dict[date]!) }
    }

    // MARK: Segment grouping within a day

    struct SegmentGroup: Identifiable {
        let section: DaySection?
        let items: [PlanItem]
        var id: String { section?.rawValue ?? "open" }
    }

    /// Groups a day's items into time-of-day segments for readability — deadline items fall into
    /// the segment containing their clock time; segment-assigned items use their explicit segment;
    /// everything else lands in a trailing "Open" group. Empty segments are omitted for past days
    /// (a historical log isn't something to plan against), but included for today/future days so
    /// every segment gets an "Add item" affordance even before it has anything in it.
    func segmentedGroups(for items: [PlanItem], includeEmpty: Bool) -> [SegmentGroup] {
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

    /// Flattens a day's items into their natural chronological reading order (segment order,
    /// then by deadline within a segment) without exposing the segment boundaries themselves —
    /// used by views that want one List Section per day rather than per time-of-day segment.
    func chronologicalOrder(for items: [PlanItem]) -> [PlanItem] {
        segmentedGroups(for: items, includeEmpty: false).flatMap(\.items)
    }
}
