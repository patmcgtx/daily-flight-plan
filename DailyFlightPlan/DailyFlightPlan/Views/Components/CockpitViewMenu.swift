//
//  CockpitViewMenu.swift
//  DailyFlightPlan
//
import SwiftUI

/// Cockpit toolbar menu of quick display toggles — flip what the day view shows in one tap
/// without opening a sheet. Shares its storage keys with `FilterSheetView`/`CockpitView`.
struct CockpitViewMenu: View {

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

    @AppStorage(AppStorageKeys.uppercaseText.rawValue)
    private var uppercaseText: Bool = true

    /// True when any option differs from its default.
    private var isNonDefault: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
            || !showCalendarEvents || !showReminderItems || !uppercaseText
    }

    var body: some View {
        Menu {
            Toggle(isOn: $showFlaggedOnly) {
                Label("Flagged Only", systemImage: "flag.fill")
            }
            Toggle(isOn: $showCompleted) {
                Label("Completed", systemImage: "checkmark")
            }
            Toggle(isOn: $showRecurring) {
                Label("Maintenance", systemImage: "wrench")
            }
            Toggle(isOn: $showCalendarEvents) {
                Label("Calendar Events", systemImage: "calendar")
            }
            Toggle(isOn: $showReminderItems) {
                Label("Reminders", systemImage: "bell")
            }

            Divider()

            Toggle(isOn: $uppercaseText) {
                Label("UPPERCASE", systemImage: "textformat")
            }
        } label: {
            // Filled circle + accent color when anything differs from its default
            Image(systemName: isNonDefault
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
                .foregroundStyle(isNonDefault ? Color.accentColor : Color.primary)
        }
        .accessibilityLabel("View Options")
    }
}
