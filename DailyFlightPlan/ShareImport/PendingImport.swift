//
//  PendingImport.swift
//  ShareImport
//
import SwiftData
import Foundation

/// Mirrors DailyFlightPlan/Persistence/PendingImport.swift. Each target compiles its own copy of
/// this model so both processes can open the same App Group-shared SwiftData store — keep the two
/// in sync if this schema changes.
@Model
class PendingImport {

    var rawText: String = ""
    var createdAt: Date = Date()
    var sourceAppName: String?

    init(rawText: String, createdAt: Date = .now, sourceAppName: String? = nil) {
        self.rawText = rawText
        self.createdAt = createdAt
        self.sourceAppName = sourceAppName
    }
}
