//
//  DeadlineItemRow.swift
//  DailyFlightPlan
//
import SwiftUI

/// A full-width row for items that have a specific clock-time deadline.
struct DeadlineItemRow: View {

    let item: PlanItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.status == .completed ? .green : .secondary)

            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let deadline = item.deadline {
                Text(deadline, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(item.title)
                .font(.subheadline)

            Spacer()

            if item.isRecurring {
                Image(systemName: "infinity")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if item.isFlagged {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }

            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview {
    DeadlineItemRow(item: PlanItem(
        title: "Team standup",
        deadline: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: .now),
        isRecurring: true
    ))
    .padding()
}
