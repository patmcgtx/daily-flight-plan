//
//  CockpitViewMenu.swift
//  DailyFlightPlan
//
import SwiftUI

/// Cockpit toolbar menu of quick display toggles — flip what the day view shows in one tap
/// without opening a sheet. Shares its storage keys with `FilterSheetView`/`CockpitView`.
struct CockpitViewMenu: View {

    /// A past day is a read-only report of plan items, so the options that only shape the live
    /// day (Completed, Calendar Events, Reminders, Empty Segments) are disabled for it.
    var isPastDay: Bool = false

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

    @AppStorage(AppStorageKeys.showEmptySegments.rawValue)
    private var showEmptySegments: Bool = true

    @AppStorage(AppStorageKeys.uppercaseText.rawValue)
    private var uppercaseText: Bool = true

    /// True when any option differs from its default.
    /// Options disabled on a past day don't count, as they aren't in effect there.
    private var isNonDefault: Bool {
        showFlaggedOnly || !showRecurring || !uppercaseText
            || (!isPastDay
                && (showCompleted || !showCalendarEvents || !showReminderItems || !showEmptySegments))
    }

    var body: some View {
        Menu {
            Toggle(isOn: $showFlaggedOnly) {
                Label("Flagged Only", systemImage: "flag.fill")
            }
            // The report always lists completed items, and never Calendar events or Reminders,
            // so a past day shows those toggles as they effectively are.
            Toggle(isOn: isPastDay ? .constant(true) : $showCompleted) {
                Label("Completed", systemImage: "checkmark")
            }
            .disabled(isPastDay)
            Toggle(isOn: $showRecurring) {
                Label("Maintenance", systemImage: "wrench")
            }
            Toggle(isOn: isPastDay ? .constant(false) : $showCalendarEvents) {
                Label("Calendar Events", systemImage: "calendar")
            }
            .disabled(isPastDay)
            Toggle(isOn: isPastDay ? .constant(false) : $showReminderItems) {
                Label("Reminders", systemImage: "bell")
            }
            .disabled(isPastDay)
            Toggle(isOn: $showEmptySegments) {
                Label("Empty Segments", systemImage: "square.dashed")
            }
            .disabled(isPastDay)

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
