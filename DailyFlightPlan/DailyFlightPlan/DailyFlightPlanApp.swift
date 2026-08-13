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
                    // Clean up any duplicates that arrived before #Unique constraints were enforced.
                    ModelContainer.deduplicateCategories(in: modelContainer.mainContext)
                    ModelContainer.deduplicateItems(in: modelContainer.mainContext)
                    // Auto-seed disabled — use Settings > Developer > Seed Sample Data instead.
                }
        }
        .modelContainer(modelContainer)
    }
}
