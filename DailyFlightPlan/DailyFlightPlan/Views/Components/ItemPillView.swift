//
//  ItemPillView.swift
//  DailyFlightPlan
//
import SwiftUI

/// A compact pill displayed in the horizontal flow within a day section or the any-time area.
struct ItemPillView: View {

    let item: PlanItem
    var isMissed: Bool = false
    var showRecurringBadge: Bool = true

    @Environment(\.editItem) private var editItem

    var body: some View {
        HStack(spacing: 5) {
            if item.status == .pending {
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        item.status = .completed
                    }
                } label: {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            Text(item.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(item.status == .pending ? .primary : .secondary)
                .strikethrough(item.status != .pending, color: .secondary)

            if isMissed, let deadline = item.deadline {
                Text(deadline, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .strikethrough()
                    .monospacedDigit()
            }
            if isMissed {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if item.isRecurring && showRecurringBadge {
                Image(systemName: "infinity")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if item.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(.regularMaterial)
        }
        .onTapGesture { editItem?(item) }
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { item.status = .canceled }
            } label: {
                Label("Cancel Item", systemImage: "xmark.circle")
            }
            Button {
                let cal = Calendar.current
                let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: item.date))!
                item.date = tomorrow
                if let deadline = item.deadline {
                    item.deadline = cal.date(byAdding: .day, value: 1, to: deadline)
                }
            } label: {
                Label("Defer to Tomorrow", systemImage: "arrow.right.circle")
            }
        }
    }
}

#Preview {
    HStack {
        ItemPillView(item: PlanItem(title: "Morning run"))
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
