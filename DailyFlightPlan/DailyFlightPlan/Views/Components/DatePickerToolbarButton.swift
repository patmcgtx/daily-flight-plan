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
        .popover(
            isPresented: $isShowingDatePicker,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            popoverContent
        }
    }

    private var popoverContent: some View {
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
        .frame(minWidth: 320, idealWidth: 340, maxWidth: .infinity, minHeight: 420, idealHeight: 440, maxHeight: 480)
        .presentationCompactAdaptation(.popover)
    }
}
