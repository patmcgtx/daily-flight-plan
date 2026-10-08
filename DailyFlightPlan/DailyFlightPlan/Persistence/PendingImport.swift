//
//  PendingImport.swift
//  DailyFlightPlan
//
import SwiftData
import Foundation

/// A chunk of raw text handed off by the Share Extension, waiting to be reviewed and converted
/// into PlanItems via the same markdown-import flow used in-app. Lives in its own App Group
/// local store (see `ModelContainer.pendingImportsContainer()`) — never synced via CloudKit,
/// since it's transient staging data cleared once reviewed.
@Model
class PendingImport {

    var rawText: String = ""
    var createdAt: Date = Date()

    /// The sharing app's display name, if available, shown to the user during review.
    var sourceAppName: String?

    init(rawText: String, createdAt: Date = .now, sourceAppName: String? = nil) {
        self.rawText = rawText
        self.createdAt = createdAt
        self.sourceAppName = sourceAppName
    }
}
