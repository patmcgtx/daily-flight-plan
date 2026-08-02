//
//  CalendarEvent.swift
//  DailyFlightPlan
//
import SwiftUI

/// A read-only snapshot of a calendar event fetched from EventKit.
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarColor: Color
}
