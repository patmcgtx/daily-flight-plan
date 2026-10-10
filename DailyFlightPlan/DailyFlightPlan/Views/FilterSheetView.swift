//
//  FilterSheetView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

/// The global filter sheet, opened from a `FilterToolbarButton` on any tab. Has a General
/// section (category selection, flagged-only) that applies everywhere, plus a Specific section
/// whose contents adapt to whichever tab opened it. Text search lives separately on each tab via
/// `InlineSearchField`.
struct FilterSheetView: View {

    let activeTab: AppTab

    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue)
    private var showFlaggedOnly: Bool = false

    @AppStorage(AppStorageKeys.showCompleted.rawValue)
    private var showCompleted: Bool = false

    @AppStorage(AppStorageKeys.showRecurring.rawValue)
    private var showRecurring: Bool = true

    @AppStorage(AppStorageKeys.showCalendarEvents.rawValue)
    private var showCalendarEvents: Bool = true

    @AppStorage(AppStorageKeys.showReminderItems.rawValue)
    private var showReminderItems: Bool = true

    @AppStorage(AppStorageKeys.showCompletedOnly.rawValue)
    private var showCompletedOnly: Bool = false

    @AppStorage(AppStorageKeys.showMissedOnly.rawValue)
    private var showMissedOnly: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CategoriesSelectFlow()
                }

                Section("General") {
                    Toggle(isOn: $showFlaggedOnly) {
                        Label("Flagged Only", systemImage: "flag.fill")
                    }
                }

                specificSection
            }
            .navigationTitle("Filters")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var specificSection: some View {
        switch activeTab {
        case .flightDeck:
            Section("Day") {
                Toggle(isOn: $showCompleted) {
                    Label("Show Completed", systemImage: "checkmark")
                }
                Toggle(isOn: $showRecurring) {
                    Label("Routines", systemImage: "infinity")
                }
                Toggle(isOn: $showCalendarEvents) {
                    Label("Calendar Events", systemImage: "calendar")
                }
                Toggle(isOn: $showReminderItems) {
                    Label("Reminders", systemImage: "bell")
                }
            }
        case .timeline:
            Section("Timeline") {
                Toggle(isOn: Binding(
                    get: { showCompletedOnly },
                    set: { newValue in
                        showCompletedOnly = newValue
                        if newValue { showMissedOnly = false }
                    }
                )) {
                    Label("Completed Only", systemImage: "checkmark")
                }
                Toggle(isOn: Binding(
                    get: { showMissedOnly },
                    set: { newValue in
                        showMissedOnly = newValue
                        if newValue { showCompletedOnly = false }
                    }
                )) {
                    Label("Missed Only", systemImage: "clock.badge.exclamationmark")
                }
            }
        case .routines, .focus, .paperPlan:
            EmptyView()
        }
    }
}

#if DEBUG

#Preview {
    Text("Host")
        .sheet(isPresented: .constant(true)) {
            FilterSheetView(activeTab: .flightDeck)
        }
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
        .injectMockServices()
}

#endif
