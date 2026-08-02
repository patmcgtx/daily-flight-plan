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
    let showNowBar: Bool
    let isCollapsed: Bool
    let onToggle: () -> Void

    private var totalCount: Int { sectionPills.count + deadlineRows.count + calendarEvents.count }

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
    }

    // MARK: Header

    private var sectionHeader: some View {
        Button(action: onToggle) {
            HStack {
                Text(section.displayName)
                    .font(.headline)

                if isCollapsed && totalCount > 0 {
                    Text("\(totalCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }

                Spacer()

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

            if !sectionPills.isEmpty {
                HFlow(itemSpacing: 8, rowSpacing: 8) {
                    ForEach(sectionPills) { item in
                        ItemPillView(item: item)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }

            if !deadlineRows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(deadlineRows) { item in
                        DeadlineItemRow(item: item)
                    }
                }
                .padding(.top, sectionPills.isEmpty ? 4 : 6)
            }

            if !calendarEvents.isEmpty {
                VStack(spacing: 0) {
                    ForEach(calendarEvents) { event in
                        CalendarEventRow(event: event)
                    }
                }
                .padding(.top, (sectionPills.isEmpty && deadlineRows.isEmpty) ? 4 : 0)
            }

            if totalCount == 0 && !showNowBar {
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
            showNowBar: true,
            isCollapsed: false,
            onToggle: {}
        )
        DaySectionView(
            section: .midday,
            sectionPills: [],
            deadlineRows: [],
            calendarEvents: [],
            showNowBar: false,
            isCollapsed: true,
            onToggle: {}
        )
    }
    .padding()
}
