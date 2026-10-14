//
//  RoutineMarkdownExporter.swift
//  DailyFlightPlan
//
import Foundation

/// Pure Markdown-rendering logic for the Routine tab's export feature. Kept separate from
/// `RoutineView` (which owns the equivalent weekday-pattern constants and naming for its own
/// schedule cards) so this can be unit tested without instantiating a SwiftUI view or a `@Query`.
enum RoutineMarkdownExporter {

    static let everyDay: Set<Locale.Weekday> = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]
    static let weekdays: Set<Locale.Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekends: Set<Locale.Weekday> = [.saturday, .sunday]
    private static let presets: [Set<Locale.Weekday>] = [everyDay, weekdays, weekends]

    // Sun-first weekday ordering/abbreviations, used to name custom (non-preset) schedules.
    private static let weekdayInfo: [(Locale.Weekday, String)] = [
        (.sunday, "Sun"), (.monday, "Mon"), (.tuesday, "Tue"),
        (.wednesday, "Wed"), (.thursday, "Thu"), (.friday, "Fri"), (.saturday, "Sat")
    ]

    /// Renders every item in `templates` (ignoring the Routine tab's own search/flag/category
    /// filters), grouped by schedule — Every Day / Weekdays / Weekends, then any custom weekday
    /// patterns sorted by their weekday-index key — with each schedule's items further grouped
    /// into day-segment subsections.
    static func export(templates: [PlanItem], now: Date = .now) -> String {
        let sections: [(name: String, pattern: Set<Locale.Weekday>)] =
            [("Every Day", everyDay), ("Weekdays", weekdays), ("Weekends", weekends)]
            + customGroups(in: templates)

        let body = sections.compactMap { section -> String? in
            let items = templates.filter { Set($0.recurringWeekdays) == section.pattern }
            let segmentBlocks = exportSegmentBlocks(for: items)
            guard !segmentBlocks.isEmpty else { return nil }
            return "## \(section.name)\n\n\(segmentBlocks.joined(separator: "\n\n"))"
        }.joined(separator: "\n\n")

        let generatedAt = now.formatted(.dateTime.month().day().year().hour().minute())
        let header = "# Routine Export\nGenerated \(generatedAt)"
        return "\(header)\n\n\(body.isEmpty ? "_No routine items yet._" : body)\n"
    }

    /// Non-preset weekday patterns present in `templates`, named and ordered the same way
    /// `RoutineView.sortedCustomGroups` orders its schedule cards.
    private static func customGroups(in templates: [PlanItem]) -> [(name: String, pattern: Set<Locale.Weekday>)] {
        var grouped: [String: Set<Locale.Weekday>] = [:]
        for template in templates {
            let days = Set(template.recurringWeekdays)
            guard !presets.contains(days) && !days.isEmpty else { continue }
            grouped[weekdayKey(days)] = days
        }
        return grouped.keys.sorted().map { key in
            let pattern = grouped[key]!
            return (sectionTitle(for: pattern), pattern)
        }
    }

    private static func weekdayKey(_ days: Set<Locale.Weekday>) -> String {
        days.compactMap { day in weekdayInfo.firstIndex(where: { $0.0 == day }) }
            .sorted()
            .map(String.init)
            .joined()
    }

    private static func sectionTitle(for days: Set<Locale.Weekday>) -> String {
        weekdayInfo.filter { days.contains($0.0) }.map(\.1).joined(separator: " · ")
    }

    /// Groups `items` by day segment (First Thing → Bedtime, then Open), sorted within each
    /// segment by deadline time then title, and renders each segment as its own `###` subsection.
    private static func exportSegmentBlocks(for items: [PlanItem]) -> [String] {
        func effectiveSection(_ item: PlanItem) -> DaySection? {
            item.daySection ?? item.deadline.flatMap { DaySection.containing($0) }
        }

        var grouped: [DaySection?: [PlanItem]] = [:]
        for item in items {
            grouped[effectiveSection(item), default: []].append(item)
        }
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

        var blocks = DaySection.allCases.compactMap { section -> String? in
            guard let sectionItems = grouped[section], !sectionItems.isEmpty else { return nil }
            return "### \(section.displayName)\n\n\(sectionItems.map { exportBlock(for: $0) }.joined(separator: "\n\n"))"
        }
        if let openItems = grouped[nil], !openItems.isEmpty {
            blocks.append("### Open\n\n\(openItems.map { exportBlock(for: $0) }.joined(separator: "\n\n"))")
        }
        return blocks
    }

    private static func exportBlock(for item: PlanItem) -> String {
        let categoryNames = (item.categories ?? [])
            .map(\.name)
            .sorted { $0.localizedCompare($1) == .orderedAscending }

        var lines = [
            "#### \(item.title)",
            "- Flagged: \(item.isFlagged ? "Yes" : "No")",
            "- Categories: \(categoryNames.isEmpty ? "None" : categoryNames.joined(separator: ", "))"
        ]
        if !item.notes.isEmpty {
            lines.append("- Notes: \(item.notes)")
        }
        return lines.joined(separator: "\n")
    }
}
