//
//  DayPlanMarkdownExporter.swift
//  DailyFlightPlan
//
import Foundation

/// Pure Markdown-rendering logic for the Cockpit (Day) tab's export feature. Kept separate
/// from `CockpitView` so this can be unit tested without instantiating a SwiftUI view or a
/// `@Query`.
enum DayPlanMarkdownExporter {

    /// Renders every item in `items` (the caller is responsible for scoping these to a single
    /// calendar day — ignoring the Cockpit tab's own search/flag/completed/category filters,
    /// since completion status is itself part of what's exported), grouped by day section.
    ///
    /// `flightNumber` and `intention` are the day's flight name and intention note; each is
    /// omitted from the header when nil/blank.
    static func export(
        items: [PlanItem], date: Date, flightNumber: String? = nil, intention: String = "",
        now: Date = .now
    ) -> String {
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
                case let (.some(da), .some(db)):
                    return da != db ? da < db : a.title.localizedCompare(b.title) == .orderedAscending
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return a.title.localizedCompare(b.title) == .orderedAscending
                }
            }
        }

        var sectionBlocks = DaySection.allCases.compactMap { section -> String? in
            guard let sectionItems = grouped[section], !sectionItems.isEmpty else { return nil }
            return "## \(section.displayName)\n\n\(sectionItems.map { exportBlock(for: $0) }.joined(separator: "\n\n"))"
        }
        if let openItems = grouped[nil], !openItems.isEmpty {
            sectionBlocks.append("## Open\n\n\(openItems.map { exportBlock(for: $0) }.joined(separator: "\n\n"))")
        }

        let dateLabel = date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        let generatedAt = now.formatted(.dateTime.month().day().year().hour().minute())
        var headerLines = ["# Day Plan Export", dateLabel]
        if let flightNumber = flightNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
           !flightNumber.isEmpty {
            headerLines.append("Flight: \(flightNumber)")
        }
        let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedIntention.isEmpty {
            // Two trailing spaces make a Markdown hard line break for multi-line intentions.
            headerLines.append("Destination: \(trimmedIntention.replacingOccurrences(of: "\n", with: "  \n"))")
        }
        headerLines.append("Generated \(generatedAt)")
        let header = headerLines.joined(separator: "\n")
        let body = sectionBlocks.isEmpty ? "_No items yet._" : sectionBlocks.joined(separator: "\n\n")
        return "\(header)\n\n\(body)\n"
    }

    private static func exportBlock(for item: PlanItem) -> String {
        let segment = item.daySection?.displayName
            ?? item.deadline.flatMap { DaySection.containing($0) }?.displayName
            ?? "Open"
        let categoryNames = (item.categories ?? [])
            .map(\.name)
            .sorted { $0.localizedCompare($1) == .orderedAscending }

        var lines = [
            "### \(item.title)",
            "- Status: \(statusLabel(item.status))",
            "- Flagged: \(item.isFlagged ? "Yes" : "No")",
            "- Routine: \(item.isRecurring ? "Yes" : "No")",
            "- Segment: \(segment)",
            "- Categories: \(categoryNames.isEmpty ? "None" : categoryNames.joined(separator: ", "))"
        ]
        if !item.notes.isEmpty {
            lines.append("- Notes: \(item.notes)")
        }
        return lines.joined(separator: "\n")
    }

    private static func statusLabel(_ status: ItemStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .canceled: return "Canceled"
        }
    }
}
