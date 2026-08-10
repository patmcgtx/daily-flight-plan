//
//  DailyFlightPlanApp.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

@main
struct DailyFlightPlanApp: App {

    @AppStorage(AppStorageKeys.theme.rawValue)
    private var theme: DFPTheme = .cupertino
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer.persistentContainer()
        } catch {
            fatalError("Failed to initialize persistent model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .injectLiveServices()
                .apply(theme: theme)
                .onAppear {
                    // ModelContainer.deduplicateCategories(in: modelContainer.mainContext)
                    // Auto-seed disabled — use Settings > Developer > Seed Sample Data instead.
                    // #if DEBUG
                    // ModelContainer.seedSampleDataIfNeeded(in: modelContainer.mainContext)
                    // #endif
                }
        }
        .modelContainer(modelContainer)
    }
}
