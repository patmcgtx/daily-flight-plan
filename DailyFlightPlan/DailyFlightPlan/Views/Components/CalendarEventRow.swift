//
//  CalendarEventRow.swift
//  DailyFlightPlan
//
import SwiftUI

/// A read-only row displaying a calendar event fetched from EventKit. Tap to open in Calendar.
struct CalendarEventRow: View {

    let event: CalendarEvent

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            let t = event.startDate.timeIntervalSinceReferenceDate
            if let url = URL(string: "calshow:\(t)") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(event.calendarColor)
                    .frame(width: 9, height: 9)

                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(event.startDate, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(event.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        CalendarEventRow(event: CalendarEvent(
            id: "1",
            title: "Team Standup",
            startDate: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!,
            endDate: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: .now)!,
            calendarTitle: "Work",
            calendarColor: .blue
        ))
        CalendarEventRow(event: CalendarEvent(
            id: "2",
            title: "Lunch with Alex",
            startDate: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!,
            endDate: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: .now)!,
            calendarTitle: "Personal",
            calendarColor: .green
        ))
    }
    .padding()
}
