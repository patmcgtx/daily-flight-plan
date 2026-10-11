//
//  DatePickerToolbarButton.swift
//  DailyFlightPlan
//
import SwiftUI

/// A toolbar button that opens a popover with a "Today" shortcut above a graphical date picker.
/// Callers own what "select a date" and "go to today" actually mean (e.g. `DayViewModel.navigate(to:)`
/// vs. `goToToday()`, which also tracks animation direction) — this view just presents the picker.
struct DatePickerToolbarButton: View {

    @Binding var selectedDate: Date
    let isToday: Bool
    let onSelectToday: () -> Void

    @State private var isShowingDatePicker = false

    var body: some View {
        Button {
            isShowingDatePicker = true
        } label: {
            Image(systemName: "calendar")
        }
        .accessibilityLabel("Choose Date")
        // `.popover` attached to a toolbar button is unreliable on macOS (NSToolbarItem-backed
        // buttons sometimes never present it at all) — a sheet is the robust equivalent there.
        // iOS keeps the popover, which presents correctly anchored to the button.
        #if os(macOS)
        .sheet(isPresented: $isShowingDatePicker) {
            macSheetContent
        }
        #else
        .popover(
            isPresented: $isShowingDatePicker,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            iOSPopoverContent
        }
        #endif
    }

    /// The "Today" row + calendar grid shared by both platforms. Sized by the caller — macOS's
    /// native graphical `DatePicker` is a small, fixed-size widget (nothing like iOS's style,
    /// which fills whatever width it's given), so the two platforms need very different frames.
    private var pickerCore: some View {
        VStack(spacing: 0) {
            Button {
                onSelectToday()
                isShowingDatePicker = false
            } label: {
                Label("Today", systemImage: "scope")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(isToday)
            .padding()

            Divider()

            DatePicker(
                "Date",
                selection: Binding(
                    get: { selectedDate },
                    set: { newDate in
                        selectedDate = newDate
                        isShowingDatePicker = false
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    #if os(macOS)
    /// Sheets don't dismiss by clicking outside the way popovers do, so this gets a proper
    /// toolbar close button instead of the floating one tried earlier — and a frame sized to
    /// the native calendar widget's actual (small) footprint, not iOS's much larger one, so the
    /// sheet doesn't end up mostly empty space around a tiny control.
    private var macSheetContent: some View {
        NavigationStack {
            pickerCore
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isShowingDatePicker = false }
                    }
                }
        }
        .frame(width: 300)
    }
    #else
    private var iOSPopoverContent: some View {
        pickerCore
            .frame(minWidth: 320, idealWidth: 340, maxWidth: .infinity, minHeight: 420, idealHeight: 440, maxHeight: 480)
            .presentationCompactAdaptation(.popover)
    }
    #endif
}
