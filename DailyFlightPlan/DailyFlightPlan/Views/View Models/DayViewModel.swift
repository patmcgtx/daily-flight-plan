//
//  DayViewModel.swift
//  DailyFlightPlan
//
import SwiftUI

@Observable @MainActor
final class DayViewModel {

    var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    var collapsedSections: Set<DaySection> = []
    private(set) var forwardNavigation: Bool = true

    // MARK: Date helpers

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// The section that contains the current clock time, or nil if not viewing today
    var currentSection: DaySection? {
        guard isToday else { return nil }
        return DaySection.containing(.now)
    }

    func goToYesterday() {
        guard let date = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        forwardNavigation = false
        selectedDate = date
    }

    func goToTomorrow() {
        guard let date = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        forwardNavigation = true
        selectedDate = date
    }

    func goToToday() {
        let today = Calendar.current.startOfDay(for: .now)
        forwardNavigation = selectedDate < today
        selectedDate = today
    }

    // MARK: Section collapse

    func isCollapsed(_ section: DaySection) -> Bool {
        collapsedSections.contains(section)
    }

    func toggleCollapsed(_ section: DaySection) {
        if collapsedSections.contains(section) {
            collapsedSections.remove(section)
        } else {
            collapsedSections.insert(section)
        }
    }

    // MARK: Item grouping

    /// Items assigned to this section via their daySection property
    func sectionPills(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.daySection == section }
    }

    /// Items with a deadline clock time that falls within this section
    func deadlineRows(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items
            .filter { item in
                guard let deadline = item.deadline, item.daySection == nil else { return false }
                return DaySection.containing(deadline) == section
            }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    /// Items with no section and no deadline (explicitly "any time")
    func anyTimeItems(from items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.daySection == nil && $0.deadline == nil }
    }
}
