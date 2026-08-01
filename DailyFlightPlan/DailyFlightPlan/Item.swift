//
//  Item.swift
//  DailyFlightPlan
//
//  Created by Patrick McGonigle on 7/24/26.
//

import Foundation
import SwiftData
import SwiftUI

enum TaskCategory: String, CaseIterable, Codable, Hashable {
    case health = "Health"
    case work = "Work"
    case personal = "Personal"
    case finance = "Finance"
    case home = "Home"

    var color: Color {
        switch self {
        case .health: return .green
        case .work: return .blue
        case .personal: return .orange
        case .finance: return .purple
        case .home: return .brown
        }
    }
}

enum TimeBlock: String, CaseIterable, Codable, Hashable {
    case morning = "Morning"
    case midday = "Midday"
    case evening = "Evening"
    case anytime = "Anytime"

    var symbolName: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "moon.fill"
        case .anytime: return "clock"
        }
    }

    var accentColor: Color {
        switch self {
        case .morning: return .orange
        case .midday: return Color(red: 0.8, green: 0.6, blue: 0.0)
        case .evening: return .indigo
        case .anytime: return Color(.systemGray)
        }
    }

    static let scheduled: [TimeBlock] = [.morning, .midday, .evening]
}

@Model
final class TaskItem {
    var title: String
    var categoryRaw: String
    var isCompleted: Bool
    var isCancelled: Bool
    var isStarred: Bool
    var isRecurring: Bool
    var urgencyLevel: Int
    var scheduledDate: Date
    var specificTime: Date?
    var timeBlockRaw: String
    var isCalendarEvent: Bool

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var timeBlock: TimeBlock {
        get { TimeBlock(rawValue: timeBlockRaw) ?? .anytime }
        set { timeBlockRaw = newValue.rawValue }
    }

    init(
        title: String,
        category: TaskCategory = .personal,
        scheduledDate: Date = Date(),
        specificTime: Date? = nil,
        timeBlock: TimeBlock = .anytime,
        isRecurring: Bool = false,
        isStarred: Bool = false,
        urgencyLevel: Int = 0,
        isCalendarEvent: Bool = false
    ) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.isCompleted = false
        self.isCancelled = false
        self.isStarred = isStarred
        self.isRecurring = isRecurring
        self.urgencyLevel = urgencyLevel
        self.scheduledDate = scheduledDate
        self.specificTime = specificTime
        self.timeBlockRaw = timeBlock.rawValue
        self.isCalendarEvent = isCalendarEvent
    }
}
