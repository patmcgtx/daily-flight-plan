//
//  ItemPillView.swift
//  DailyFlightPlan
//
import SwiftUI

/// A compact pill displayed in the horizontal flow within a day section or the any-time area.
struct ItemPillView: View {

    let item: PlanItem

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.status == .completed ? .green : .secondary)
                .font(.subheadline)

            Text(item.title)
                .font(.subheadline)
                .lineLimit(1)

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
        .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    HStack {
        ItemPillView(item: PlanItem(title: "Morning run", isRecurring: true))
        ItemPillView(item: PlanItem(title: "Expense report", isFlagged: true))
        ItemPillView(item: PlanItem(title: "Coffee"))
    }
    .padding()
}
