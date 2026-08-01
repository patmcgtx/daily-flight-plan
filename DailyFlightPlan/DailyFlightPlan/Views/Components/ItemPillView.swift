//
//  ItemPillView.swift
//  DailyFlightPlan
//
import SwiftUI

/// A compact pill displayed in the horizontal flow within a day section or the any-time area.
struct ItemPillView: View {

    let item: PlanItem
    var isMissed: Bool = false

    @State private var dragOffset: CGFloat = 0

    // Minimum predicted end translation (pt) to commit a flick
    private let flickThreshold: CGFloat = 80

    var body: some View {
        pillContent
            .overlay(alignment: .top) {
                flickHint
                    .offset(y: -20)
            }
            .offset(x: dragOffset)
            .opacity(dragOffset == 0 ? 1 : max(0.5, 1 - abs(dragOffset) / 250))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let h = abs(value.translation.width)
                        let v = abs(value.translation.height)
                        guard h > v else { return }
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let predicted = value.predictedEndTranslation.width
                        if predicted < -flickThreshold {
                            flickAway(leading: true) { item.status = .canceled }
                        } else if predicted > flickThreshold {
                            flickAway(leading: false) {
                                let cal = Calendar.current
                                let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: item.date))!
                                item.date = tomorrow
                                if let deadline = item.deadline {
                                    item.deadline = cal.date(byAdding: .day, value: 1, to: deadline)
                                }
                            }
                        } else {
                            withAnimation(.spring(duration: 0.4)) { dragOffset = 0 }
                        }
                    }
            )
    }

    private var pillContent: some View {
        HStack(spacing: 5) {
            Button {
                guard item.status != .canceled else { return }
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
                .foregroundStyle(.primary)
                .strikethrough(item.status == .canceled, color: .secondary)

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

            if item.isRecurring {
                Image(systemName: "infinity")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if item.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(.regularMaterial)
        }
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
            Button { } label: {
                Label("Edit…", systemImage: "pencil")
            }
        }
    }

    @ViewBuilder
    private var flickHint: some View {
        if dragOffset < -8 {
            Text("Cancel")
                .font(.caption2.bold())
                .foregroundStyle(.red)
                .opacity(min(1, (abs(dragOffset) - 8) / 50))
        } else if dragOffset > 8 {
            Text("Defer")
                .font(.caption2.bold())
                .foregroundStyle(.green)
                .opacity(min(1, (dragOffset - 8) / 50))
        }
    }

    private func flickAway(leading: Bool, action: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = leading ? -500 : 500
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            action()
            dragOffset = 0
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
