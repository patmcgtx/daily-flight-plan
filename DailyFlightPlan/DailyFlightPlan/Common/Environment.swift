//
//  Environment.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

extension EnvironmentValues {

    // MARK: Service dependency injection
    //
    // Services are injected via InjectLiveServicesModifier (or InjectMockServicesModifier in
    // DEBUG). Views that use a service should declare it as an optional @Environment property;
    // the service will be nil only in previews that don't call injectMockServices().

    @Entry var categorySelectionService: CategorySelectionService? = nil

    // Phase 7: CalendarService will be added here

    // MARK: Actions

    /// Invoke to open the edit form for the given item. Set by DayView via .environment(\.editItem, ...).
    @Entry var editItem: ((PlanItem) -> Void)? = nil

    // MARK: Default settings

    @Entry var dfpTheme: DFPTheme = .cupertino
}

extension View {
    func injectLiveServices() -> some View {
        self.modifier(InjectLiveServicesModifier())
    }
}

/// Injects all live services into the environment. Add new services here as phases are completed.
struct InjectLiveServicesModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .environment(\.categorySelectionService, CategorySelectionService(modelContext: modelContext))
    }
}

#if DEBUG

struct InjectMockServicesModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .environment(\.categorySelectionService, CategorySelectionService(modelContext: modelContext))
    }
}

extension View {
    func injectMockServices() -> some View {
        self.modifier(InjectMockServicesModifier())
    }
}

#endif
