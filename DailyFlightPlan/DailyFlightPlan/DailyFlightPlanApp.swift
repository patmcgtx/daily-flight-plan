//
//  DailyFlightPlanApp.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
#if os(macOS)
import CoreText
#endif

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
        Self.registerPaperPlanFontsIfNeeded()
    }

    /// `Info.plist`'s `UIAppFonts` only registers fonts on iOS-family platforms — macOS ignores
    /// it entirely, so IBM Plex Mono (used by the Flight tab's paper styling) needs explicit
    /// Core Text registration there instead, or `Font.custom` silently falls back to the system
    /// font on Mac.
    private static func registerPaperPlanFontsIfNeeded() {
        #if os(macOS)
        for name in ["IBMPlexMono-Regular", "IBMPlexMono-SemiBold", "IBMPlexMono-Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .injectLiveServices()
                .apply(theme: theme)
                .onAppear {
                    ModelContainer.deduplicateCategories(in: modelContainer.mainContext)
                    ModelContainer.deduplicateItems(in: modelContainer.mainContext)
                    // Auto-seed disabled — use Settings > Developer > Seed Sample Data instead.
                }
        }
        .modelContainer(modelContainer)
    }
}
