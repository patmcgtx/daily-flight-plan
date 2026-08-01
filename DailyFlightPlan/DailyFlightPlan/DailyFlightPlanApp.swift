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
        }
        .modelContainer(modelContainer)
    }
}
