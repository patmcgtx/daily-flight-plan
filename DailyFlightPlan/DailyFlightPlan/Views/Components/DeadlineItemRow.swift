//
//  DeadlineItemRow.swift
//  DailyFlightPlan
//
import SwiftUI

/// A full-width row for items that have a specific clock-time deadline.
struct DeadlineItemRow: View {

    let item: PlanItem

    @Environment(\.editItem) private var editItem

    @State private var dragOffset: CGFloat = 0

    private let flickThreshold: CGFloat = 80

    var body: some View {
        rowContent
            .overlay(alignment: .top) {
                flickHint
                    .offset(y: -18)
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

    private var rowContent: some View {
        HStack(spacing: 10) {
            Button {
                guard item.status != .canceled else { return }
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
                Image(systemName: "flag.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
