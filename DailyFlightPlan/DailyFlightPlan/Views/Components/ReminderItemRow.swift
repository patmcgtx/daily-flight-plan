//
//  ReminderItemRow.swift
//  DailyFlightPlan
//
import SwiftUI

/// A read-only row displaying a Reminders item fetched from EventKit.
struct ReminderItemRow: View {

    let item: ReminderItem

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(item.listColor)
                .frame(width: 3)

            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let dueDate = item.dueDate {
                    Text(dueDate, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(item.title)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ReminderItemRow(item: ReminderItem(
            id: "1",
            title: "Review PR before EOD",
            notes: nil,
            dueDate: Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: .now)!,
            listTitle: "Work",
            listColor: .blue,
            isCompleted: false
        ))
        ReminderItemRow(item: ReminderItem(
            id: "2",
            title: "Pick up dry cleaning",
            notes: nil,
            dueDate: nil,
            listTitle: "Home",
            listColor: .orange,
            isCompleted: false
        ))
    }
    .padding()
}
