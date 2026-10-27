//
//  Day.swift
//  DailyFlightPlan
//
import SwiftData
import Foundation

/// Per-calendar-day details the user can customize: the day's flight name and its intention.
///
/// Rows are created lazily the first time the user edits either field, so most days have no
/// `Day` at all. Items are matched to a day by date, not by a relationship, which keeps this
/// model free of CloudKit's relationship/inverse requirements. CloudKit also forbids unique
/// constraints, so two devices can each create a row for the same date — see
/// `ModelContainer.deduplicateDays(in:)`.
@Model
class Day {

    /// Start-of-day of the calendar day this row describes. Always normalized via `normalized(_:)`.
    var date: Date = Date()

    /// The user's custom flight name. Empty means "use the default `DFP YYYYMMDD` number".
    var flightName: String = ""

    /// The day's intention / "destination" note. Empty means none has been written.
    var intention: String = ""

    /// Last edit time, used to pick a winner when merging duplicate rows.
    var modifiedAt: Date = Date()

    init(date: Date, flightName: String = "", intention: String = "") {
        self.date = Day.normalized(date)
        self.flightName = flightName
        self.intention = intention
    }

    static let maxFlightNameLength = 24

    /// Updates the flight name (capped at `maxFlightNameLength`) and stamps `modifiedAt`.
    func setFlightName(_ name: String) {
        flightName = String(name.prefix(Day.maxFlightNameLength))
        modifiedAt = Date()
    }

    /// Updates the intention and stamps `modifiedAt`.
    func setIntention(_ text: String) {
        intention = text
        modifiedAt = Date()
    }

    /// True when the user hasn't customized anything on this day.
    var isBlank: Bool {
        flightName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The lookup key for a day: its start-of-day in the current calendar.
    static func normalized(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// The auto-generated mock flight number: "DFP" plus the date as YYYYMMDD.
    static func defaultFlightNumber(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "DFP \(comps.year ?? 0)\(String(format: "%02d", comps.month ?? 0))\(String(format: "%02d", comps.day ?? 0))"
    }

    /// The flight name to display: the user's entry if it isn't blank, else the default number.
    var displayFlightNumber: String {
        let trimmed = flightName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Day.defaultFlightNumber(for: date) : trimmed
    }
}
