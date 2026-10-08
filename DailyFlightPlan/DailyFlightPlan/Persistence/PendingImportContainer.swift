//
//  PendingImportContainer.swift
//  DailyFlightPlan
//
import SwiftData
import Foundation

/// App Group identifier shared between the main app and the ShareImport extension, used only
/// for the local-only PendingImport backlog store (not the CloudKit-synced PlanItem store).
let pendingImportsAppGroupID = "group.com.patmcg.DailyFlightPlan"

extension ModelContainer {

    /// Creates the local-only (no CloudKit) container for the share-extension import backlog,
    /// stored in the shared App Group container so both the main app and the extension — each
    /// their own process — read and write the same file directly, with no sync round-trip.
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
