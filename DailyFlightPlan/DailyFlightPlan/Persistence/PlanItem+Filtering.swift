//
//  PlanItem+Filtering.swift
//  DailyFlightPlan
//
import Foundation

/// Shared filtering predicates used by the global filter sheet across Day/Timeline/Routine.
/// Pure and stateless — no SwiftData/environment dependency — so it's trivially unit-testable.
extension Sequence where Element == PlanItem {

    /// Matches `title`/`notes` against `text`. An empty (or whitespace-only) `text` is a no-op.
    func matchingSearchText(_ text: String) -> [PlanItem] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(self) }
        return filter {
            $0.title.localizedStandardContains(query) || $0.notes.localizedStandardContains(query)
        }
    }

    /// FlightPlanView's (Day tab) status predicate — reveal semantics: `showCompleted` shows
    /// completed/canceled items alongside everything else, rather than isolating to just them.
    func matchingDayStatusFilters(
        showFlaggedOnly: Bool, showCompleted: Bool, showRecurring: Bool
    ) -> [PlanItem] {
        filter {
            (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
            && (showRecurring || !$0.isRecurring)
        }
    }

    /// TimelineView's status predicate — isolate semantics: `showCompletedOnly`/`showMissedOnly`
    /// narrow down to just that subset, rather than revealing it alongside everything else.
    /// `isMissed` is injected since it depends on `Date.now`/`Calendar`, which stay view-local.
    func matchingTimelineStatusFilters(
        showFlaggedOnly: Bool,
        showCompletedOnly: Bool,
        showMissedOnly: Bool,
        isMissed: (PlanItem) -> Bool
    ) -> [PlanItem] {
        filter { item in
            ((item.status == .completed || item.status == .canceled) == showCompletedOnly)
            && (!showFlaggedOnly || item.isFlagged)
            && (!showMissedOnly || isMissed(item))
        }
    }
}
