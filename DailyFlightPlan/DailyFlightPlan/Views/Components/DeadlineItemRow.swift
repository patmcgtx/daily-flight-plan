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
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                }
            } label: {
                Image(systemName: completionIcon)
                    .foregroundStyle(completionColor)
            }
            .buttonStyle(.plain)

            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let deadline = item.deadline {
                Text(deadline, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .strikethrough(item.status == .canceled)
            }

            Text(item.title)
                .font(.subheadline)
                .strikethrough(item.status == .canceled, color: .secondary)
                .foregroundStyle(item.status == .canceled ? .secondary : .primary)

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
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { item.status = .canceled }
            } label: {
                Label("Cancel Item", systemImage: "xmark.circle")
            }
            Button {
                let tomorrow = Calendar.current.date(
                    byAdding: .day, value: 1,
                    to: Calendar.current.startOfDay(for: .now)
                )!
                item.date = tomorrow
                if let deadline = item.deadline {
                    item.deadline = Calendar.current.date(byAdding: .day, value: 1, to: deadline)
                }
            } label: {
                Label("Defer to Tomorrow", systemImage: "arrow.right.circle")
            }
            Button { } label: {
                Label("Edit…", systemImage: "pencil")
            }
        }
    }

    private var completionIcon: String {
        switch item.status {
        case .completed: "checkmark.circle.fill"
        case .canceled:  "xmark.circle.fill"
        case .pending:   "circle"
        }
    }

    private var completionColor: Color {
        switch item.status {
        case .completed: .green
        case .canceled:  .secondary
        case .pending:   .secondary
        }
    }
}

#Preview {
    VStack {
        DeadlineItemRow(item: PlanItem(
            title: "Team standup",
            deadline: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: .now),
            isRecurring: true
        ))
        DeadlineItemRow(item: PlanItem(
            title: "Doctor appointment",
            isFlagged: true,
            deadline: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: .now),
            status: .completed
        ))
    }
    .padding()
}
