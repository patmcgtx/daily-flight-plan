//
//  PendingImportContainer.swift
//  ShareImport
//
import SwiftData
import Foundation

/// Mirrors DailyFlightPlan/Persistence/PendingImportContainer.swift — keep the App Group ID and
/// store filename in sync with the main app's copy, since both must resolve to the same file.
let pendingImportsAppGroupID = "group.com.patmcg.DailyFlightPlan"

extension ModelContainer {
    static func pendingImportsContainer() throws -> ModelContainer {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: pendingImportsAppGroupID
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let config = ModelConfiguration(
            url: groupURL.appendingPathComponent("PendingImports.sqlite")
        )
        return try ModelContainer(for: PendingImport.self, configurations: config)
    }
}
