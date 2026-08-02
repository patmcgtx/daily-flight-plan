//
//  CalendarInfo.swift
//  DailyFlightPlan
//
import SwiftUI

/// Lightweight metadata about a calendar (used for selection UI).
struct CalendarInfo: Identifiable {
    let id: String
    let title: String
    let color: Color
}
