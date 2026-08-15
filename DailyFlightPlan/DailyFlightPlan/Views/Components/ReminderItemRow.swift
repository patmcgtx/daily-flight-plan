//
//  ReminderItemRow.swift
//  DailyFlightPlan
//
import SwiftUI

/// A read-only row displaying a Reminders item fetched from EventKit.
struct ReminderItemRow: View {

    let item: ReminderItem

    @Environment(\.importReminderItem) private var importReminderItem
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: "x-apple-reminderkit://") {
                openURL(url)
            }
        } label: {
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

                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let importReminderItem {
                Button {
                    importReminderItem(item)
                } label: {
                    Label("Import as Task", systemImage: "square.and.arrow.down")
                }
            }
            Button {
                if let url = URL(string: "x-apple-reminderkit://") {
                    openURL(url)
                }
            } label: {
                Label("Open in Reminders", systemImage: "arrow.up.right.square")
            }
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
