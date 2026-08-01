//
//  Environment.swift
//  DailyFlightPlan
//
import SwiftUI

extension EnvironmentValues {

    // MARK: Service dependency injection
    //
    // Services are injected via InjectLiveServicesModifier (or InjectMockServicesModifier in
    // DEBUG). Crashing on nil is intentional — a missing service means the app cannot function.

    // Phase 5: CalendarService will be added here

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
    func body(content: Content) -> some View {
        content
        // Additional services injected in later phases
    }
}

#if DEBUG

struct InjectMockServicesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
        // Mock services injected in later phases
    }
}

extension View {
    func injectMockServices() -> some View {
        self.modifier(InjectMockServicesModifier())
    }
}

#endif
