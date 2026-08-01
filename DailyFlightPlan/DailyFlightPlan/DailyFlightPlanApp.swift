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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .injectLiveServices()
                .apply(theme: theme)
        }
        .modelContainer(try! ModelContainer.persistentContainer())
    }
}
