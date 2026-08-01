//
//  ItemPillView.swift
//  DailyFlightPlan
//
import SwiftUI

/// A compact pill displayed in the horizontal flow within a day section or the any-time area.
struct ItemPillView: View {

    let item: PlanItem
    var isMissed: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                }
            } label: {
                Image(systemName: completionIcon)
                    .foregroundStyle(completionColor)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(isMissed ? .orange : .primary)
                .strikethrough(item.status == .canceled, color: .secondary)

            if isMissed, let deadline = item.deadline {
                Text(deadline, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .strikethrough()
                    .monospacedDigit()
            }

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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(.regularMaterial)
            if isMissed { Capsule().fill(.orange.opacity(0.15)) }
        }
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
        case .pending:   isMissed ? .orange : .secondary
        }
    }
}

#Preview {
    HStack {
        ItemPillView(item: PlanItem(title: "Morning run", isRecurring: true))
        ItemPillView(item: PlanItem(title: "Expense report", isFlagged: true))
        ItemPillView(
            item: PlanItem(
                title: "Team standup",
                deadline: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: .now)
            ),
            isMissed: true
        )
    }
    .padding()
}
