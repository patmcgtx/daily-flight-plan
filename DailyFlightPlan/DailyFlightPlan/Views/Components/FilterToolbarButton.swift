//
//  FilterToolbarButton.swift
//  DailyFlightPlan
//
import SwiftUI

/// The single filter entry point shared by Day/Timeline/Routine's toolbars. Opens
/// `FilterSheetView` as a popover anchored to this button, and fills its icon when any filter
/// relevant to `activeTab` is currently active.
struct FilterToolbarButton: View {

    let activeTab: AppTab
    @Binding var searchText: String

    @State private var isShowingFilterSheet = false

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

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

    private var isGeneralFilterActive: Bool {
        showFlaggedOnly
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (categorySelectionService?.hasSelectedCategories ?? false)
    }

    private var isFilterActive: Bool {
        switch activeTab {
        case .flightDeck:
            return isGeneralFilterActive || showCompleted || !showRecurring
                || !showCalendarEvents || !showReminderItems
        case .timeline:
            return isGeneralFilterActive || showCompletedOnly || showMissedOnly
        case .routines, .focus:
            return isGeneralFilterActive
        }
    }

    var body: some View {
        Button {
            isShowingFilterSheet = true
        } label: {
            Image(systemName: isFilterActive
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
                .foregroundStyle(isFilterActive ? Color.accentColor : Color.primary)
        }
        .accessibilityLabel("Filters")
        .popover(isPresented: $isShowingFilterSheet) {
            FilterSheetView(activeTab: activeTab, searchText: $searchText)
        }
    }
}
