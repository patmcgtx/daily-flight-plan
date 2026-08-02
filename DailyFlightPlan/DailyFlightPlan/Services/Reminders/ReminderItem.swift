//
//  ReminderItem.swift
//  DailyFlightPlan
//
import SwiftUI

struct ReminderItem: Identifiable {
    let id: String
    let title: String
    let notes: String?
    /// Specific due time, or nil if the reminder has a date but no time.
    let dueDate: Date?
    let listTitle: String
    let listColor: Color
    let isCompleted: Bool
}
