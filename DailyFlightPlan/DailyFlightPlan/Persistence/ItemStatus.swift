//
//  ItemStatus.swift
//  DailyFlightPlan
//

enum ItemStatus: String, Codable {
    case pending
    case completed
    case canceled
    case deferred
}
