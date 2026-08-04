//
//  DaySectionView.swift
//  DailyFlightPlan
//
import SwiftUI
import Flow

/// A collapsible rounded-rect card representing one time-of-day section.
struct DaySectionView: View {

    let section: DaySection
    let sectionPills: [PlanItem]
    let deadlineRows: [PlanItem]
    let calendarEvents: [CalendarEvent]
    let reminderItems: [ReminderItem]
    var projectedPills: [PlanItem] = []
    var summary: String? = nil
    let showNowBar: Bool
    let isCollapsed: Bool
    let onToggle: () -> Void
    /// Called with the item's UUID string when a pill is dropped onto this section.
    var onDropItem: ((String) -> Void)? = nil

    @State private var isDropTargeted = false

    private var totalCount: Int {
        // Projected pills are not counted — they're not committed items
        sectionPills.count + deadlineRows.count + calendarEvents.count + reminderItems.count
    }

    private var regularPills: [PlanItem] {
        sectionPills.filter { $0.status == .pending && !$0.isRecurring }
    }

    private var habitPills: [PlanItem] {
        sectionPills.filter { $0.status == .pending && $0.isRecurring }
    }

    private var donePills: [PlanItem] {
        sectionPills.filter { $0.status == .completed }
    }

    private var canceledPills: [PlanItem] {
        sectionPills.filter { $0.status == .canceled }
    }

    private var hasAnyPills: Bool {
        !regularPills.isEmpty || !habitPills.isEmpty || !projectedPills.isEmpty || !donePills.isEmpty || !canceledPills.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            if !isCollapsed {
                Divider()
                sectionContent
            }
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator, lineWidth: 0.5)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let uuidString = items.first, let onDropItem else { return false }
            onDropItem(uuidString)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    // MARK: Helpers

    private func labeledPillRow(icon: String, pills: [PlanItem], isFirst: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
                .padding(.top, 7)
            HFlow(itemSpacing: 8, rowSpacing: 8) {
                ForEach(pills) { item in
                    ItemPillView(item: item)
                        .draggable(item.uuid.uuidString)
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.top, isFirst ? 10 : 6)
    }

    // MARK: Header

    private var sectionHeader: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 8) {
                if isCollapsed, let summary {
                    Text("\(Text(section.displayName).font(.headline))  \(Text(section.timeRangeLabel).font(.caption).foregroundStyle(.tertiary))  \(Text(summary).font(.caption).foregroundStyle(.secondary))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 6) {
                        Text(section.displayName)
                            .font(.headline)
                        Text(section.timeRangeLabel)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if isCollapsed && totalCount > 0 {
                            Text("\(totalCount)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                    }
                }

                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showNowBar {
                NowBarView()
                    .padding(.vertical, 8)
            }

            if !regularPills.isEmpty {
                HFlow(itemSpacing: 8, rowSpacing: 8) {
                    ForEach(regularPills) { item in
                        ItemPillView(item: item)
                            .draggable(item.uuid.uuidString)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }

            if !donePills.isEmpty {
                labeledPillRow(icon: "checkmark", pills: donePills, isFirst: regularPills.isEmpty)
            }

            if !canceledPills.isEmpty {
                labeledPillRow(icon: "xmark", pills: canceledPills, isFirst: regularPills.isEmpty && donePills.isEmpty)
            }

            if !habitPills.isEmpty || !projectedPills.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "infinity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                        .padding(.top, 7)
                    HFlow(itemSpacing: 8, rowSpacing: 8) {
                        ForEach(habitPills) { item in
                            ItemPillView(item: item, showRecurringBadge: false)
                                .draggable(item.uuid.uuidString)
                        }
                        ForEach(projectedPills) { item in
                            ItemPillView(item: item, showRecurringBadge: false)
                                .opacity(0.35)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 14)
                .padding(.top, (regularPills.isEmpty && donePills.isEmpty && canceledPills.isEmpty) ? 10 : 6)
            }

            if !deadlineRows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(deadlineRows) { item in
                        DeadlineItemRow(item: item)
                            .draggable(item.uuid.uuidString)
                    }
                }
                .padding(.top, hasAnyPills ? 6 : 4)
            }

            if !calendarEvents.isEmpty {
                VStack(spacing: 0) {
                    ForEach(calendarEvents) { event in
                        CalendarEventRow(event: event)
                    }
                }
                .padding(.top, (sectionPills.isEmpty && deadlineRows.isEmpty) ? 4 : 0)
            }

            if !reminderItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(reminderItems) { item in
                        ReminderItemRow(item: item)
                    }
                }
                .padding(.top, (sectionPills.isEmpty && deadlineRows.isEmpty && calendarEvents.isEmpty) ? 4 : 0)
            }

            if !hasAnyPills && deadlineRows.isEmpty && calendarEvents.isEmpty && reminderItems.isEmpty && !showNowBar {
                Text("Nothing scheduled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    let now = Date.now
    let deadline = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: now)!
    let calEvent = CalendarEvent(
        id: "mock-1",
        title: "Team Standup",
        startDate: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now)!,
        endDate: Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: now)!,
        calendarTitle: "Work",
        calendarColor: .blue
    )
    let reminder = ReminderItem(
        id: "mock-r1",
        title: "Send status update",
        notes: nil,
        dueDate: Calendar.current.date(bySettingHour: 9, minute: 45, second: 0, of: now)!,
        listTitle: "Work",
        listColor: .blue,
        isCompleted: false
    )
    return VStack(spacing: 12) {
        DaySectionView(
            section: .morning,
            sectionPills: [
                PlanItem(title: "Morning run", isRecurring: true),
                PlanItem(title: "Coffee", isRecurring: true),
            ],
            deadlineRows: [
                PlanItem(title: "Doctor appt", deadline: deadline, isRecurring: true),
            ],
            calendarEvents: [calEvent],
            reminderItems: [reminder],
            showNowBar: true,
            isCollapsed: false,
            onToggle: {}
        )
        DaySectionView(
            section: .midday,
            sectionPills: [],
            deadlineRows: [],
            calendarEvents: [],
            reminderItems: [],
            showNowBar: false,
            isCollapsed: true,
            onToggle: {}
        )
    }
    .padding()
}
