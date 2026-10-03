//
//  PlanItemFilteringTests.swift
//  DailyFlightPlanTests
//

import Testing
import Foundation
@testable import DailyFlightPlan

struct PlanItemFilteringTests {

    private func item(
        title: String = "Item",
        notes: String = "",
        isFlagged: Bool = false,
        status: ItemStatus = .pending,
        isTemplate: Bool = false,
        template: PlanItem? = nil
    ) -> PlanItem {
        let item = PlanItem(title: title, notes: notes, isFlagged: isFlagged, isTemplate: isTemplate, status: status)
        item.template = template
        return item
    }

    // MARK: matchingSearchText

    @Test("matchingSearchText with an empty or whitespace-only query returns every item unchanged", arguments: [
        "", "   ",
    ])
    func matchingSearchTextEmptyQueryIsNoOp(query: String) {
        let items = [item(title: "Buy milk"), item(title: "Walk the dog")]
        #expect(items.matchingSearchText(query).map(\.uuid) == items.map(\.uuid))
    }

    @Test("matchingSearchText matches against title or notes, case-insensitively", arguments: [
        (title: "Buy milk", notes: "", query: "milk", matches: true),
        (title: "Buy milk", notes: "", query: "MILK", matches: true),
        (title: "Buy milk", notes: "", query: "eggs", matches: false),
        (title: "Errand", notes: "pick up dry cleaning", query: "cleaning", matches: true),
        (title: "Errand", notes: "pick up dry cleaning", query: "milk", matches: false),
    ])
    func matchingSearchTextMatchesTitleOrNotes(title: String, notes: String, query: String, matches: Bool) {
        let subject = item(title: title, notes: notes)
        let result = [subject].matchingSearchText(query)
        #expect(result.contains(subject) == matches)
    }

    // MARK: matchingDayStatusFilters

    @Test(
        "matchingDayStatusFilters reveals completed/canceled items alongside everything else when showCompleted is on",
        arguments: [
            (status: ItemStatus.pending, showCompleted: false, included: true),
            (status: ItemStatus.completed, showCompleted: false, included: false),
            (status: ItemStatus.canceled, showCompleted: false, included: false),
            (status: ItemStatus.completed, showCompleted: true, included: true),
            (status: ItemStatus.canceled, showCompleted: true, included: true),
        ]
    )
    func matchingDayStatusFiltersRevealSemantics(status: ItemStatus, showCompleted: Bool, included: Bool) {
        let subject = item(status: status)
        let result = [subject].matchingDayStatusFilters(
            showFlaggedOnly: false, showCompleted: showCompleted, showRecurring: true
        )
        #expect(result.contains(subject) == included)
    }

    @Test("matchingDayStatusFilters requires isFlagged when showFlaggedOnly is on")
    func matchingDayStatusFiltersFlaggedOnly() {
        let flagged = item(isFlagged: true)
        let unflagged = item(isFlagged: false)
        let result = [flagged, unflagged].matchingDayStatusFilters(
            showFlaggedOnly: true, showCompleted: true, showRecurring: true
        )
        #expect(result.map(\.uuid) == [flagged.uuid])
    }

    @Test("matchingDayStatusFilters excludes recurring items when showRecurring is off")
    func matchingDayStatusFiltersRecurring() {
        let template = item(isTemplate: true)
        let recurringInstance = item(template: template)
        let oneOff = item()
        let result = [recurringInstance, oneOff].matchingDayStatusFilters(
            showFlaggedOnly: false, showCompleted: true, showRecurring: false
        )
        #expect(result.map(\.uuid) == [oneOff.uuid])
    }

    // MARK: matchingTimelineStatusFilters

    @Test(
        "matchingTimelineStatusFilters isolates to completed/canceled only when showCompletedOnly is on",
        arguments: [
            (status: ItemStatus.pending, showCompletedOnly: false, included: true),
            (status: ItemStatus.completed, showCompletedOnly: false, included: false),
            (status: ItemStatus.pending, showCompletedOnly: true, included: false),
            (status: ItemStatus.completed, showCompletedOnly: true, included: true),
            (status: ItemStatus.canceled, showCompletedOnly: true, included: true),
        ]
    )
    func matchingTimelineStatusFiltersIsolateSemantics(status: ItemStatus, showCompletedOnly: Bool, included: Bool) {
        let subject = item(status: status)
        let result = [subject].matchingTimelineStatusFilters(
            showFlaggedOnly: false, showCompletedOnly: showCompletedOnly, showMissedOnly: false, isMissed: { _ in false }
        )
        #expect(result.contains(subject) == included)
    }

    @Test("matchingTimelineStatusFilters requires isFlagged when showFlaggedOnly is on")
    func matchingTimelineStatusFiltersFlaggedOnly() {
        let flagged = item(isFlagged: true)
        let unflagged = item(isFlagged: false)
        let result = [flagged, unflagged].matchingTimelineStatusFilters(
            showFlaggedOnly: true, showCompletedOnly: false, showMissedOnly: false, isMissed: { _ in false }
        )
        #expect(result.map(\.uuid) == [flagged.uuid])
    }

    @Test("matchingTimelineStatusFilters defers missed-ness to the injected isMissed closure")
    func matchingTimelineStatusFiltersMissedOnly() {
        let missed = item(title: "Missed")
        let notMissed = item(title: "Not missed")
        let result = [missed, notMissed].matchingTimelineStatusFilters(
            showFlaggedOnly: false, showCompletedOnly: false, showMissedOnly: true,
            isMissed: { $0.title == "Missed" }
        )
        #expect(result.map(\.uuid) == [missed.uuid])
    }
}
