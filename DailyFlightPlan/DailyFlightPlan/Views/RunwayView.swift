//
//  RunwayView.swift
//  DailyFlightPlan
//
//  Paper-planner aesthetic: flat checklist with ruled section dividers.
//  No glass cards — just clean typography and a thin accent bar on the active section.
//
import SwiftUI
import SwiftData

struct RunwayView: View {

    var viewModel: DayViewModel

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @Environment(\.modelContext) private var modelContext
    @State private var itemToEdit: PlanItem?
    @State private var isAddingItem = false

    private var dateItems: [PlanItem] {
        allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate) }
    }
    private var activeItems: [PlanItem] { dateItems.filter { $0.status != .canceled } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                dateNavHeader
                progressStrip
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                ForEach(DaySection.allCases) { section in
                    runwaySection(section)
                }

                let openItems = viewModel.anyTimeItems(from: activeItems)
                if !openItems.isEmpty {
                    sectionDivider(label: "OPEN", isCurrent: false)
                    ForEach(openItems) { item in checkRow(item) }
                }

                Spacer(minLength: 80)
            }
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(isPresented: $isAddingItem) { ItemForm(date: viewModel.selectedDate) }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
    }

    // MARK: Header

    private var dateNavHeader: some View {
        HStack {
            Button { withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToYesterday() } } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(viewModel.selectedDate, format: .dateTime.month(.wide).day())
                    .font(.title.bold())
                    .monospacedDigit()
            }

            Spacer()

            Button { withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToTomorrow() } } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    // MARK: Progress strip

    private var progressStrip: some View {
        let total = activeItems.count
        let done = activeItems.filter { $0.status == .completed }.count
        let pct = total > 0 ? Double(done) / Double(total) : 0
        return HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.12)).frame(height: 3)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * pct, height: 3)
                        .animation(.spring(duration: 0.4), value: done)
                }
            }
            .frame(height: 3)
            Text(total > 0 ? "\(done)/\(total)" : "")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: Section block

    @ViewBuilder
    private func runwaySection(_ section: DaySection) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems)
        let deadlines = viewModel.deadlineRows(section, from: activeItems)
        let isCurrent = viewModel.currentSection == section && viewModel.isToday

        VStack(alignment: .leading, spacing: 0) {
            sectionDivider(label: section.displayName.uppercased(), isCurrent: isCurrent,
                           timeRange: section.timeRangeLabel)

            if pills.isEmpty && deadlines.isEmpty {
                HStack(spacing: 0) {
                    accentBar(isCurrent: isCurrent)
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                        .padding(.leading, 16)
                        .padding(.vertical, 6)
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    accentBar(isCurrent: isCurrent)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(pills) { item in checkRow(item) }
                        ForEach(deadlines) { item in deadlineCheckRow(item) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func sectionDivider(label: String, isCurrent: Bool, timeRange: String? = nil) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isCurrent ? Color.accentColor : Color.clear)
                .frame(width: 3)

            HStack(spacing: 6) {
                if isCurrent {
                    Circle().fill(.red).frame(width: 5, height: 5)
                }
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                    .kerning(1.1)
                if let tr = timeRange {
                    Text(tr)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Rectangle()
                    .fill(isCurrent ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2))
                    .frame(height: 0.5)
                    .frame(maxWidth: 80)
            }
            .padding(.leading, 12)
            .padding(.trailing, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func accentBar(isCurrent: Bool) -> some View {
        Rectangle()
            .fill(isCurrent ? Color.accentColor.opacity(0.25) : Color.clear)
            .frame(width: 3)
    }

    // MARK: Row types

    private func checkRow(_ item: PlanItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.body)
                .strikethrough(item.status == .completed)
                .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if item.isFlagged {
                    Image(systemName: "flag.fill").font(.caption2).foregroundStyle(.orange)
                }
                if item.isRecurring {
                    Image(systemName: "infinity").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
    }

    private func deadlineCheckRow(_ item: PlanItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .strikethrough(item.status == .completed)
                    .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                if let dl = item.deadline {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2)
                        Text(dl, format: .dateTime.hour().minute())
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isFlagged {
                Image(systemName: "flag.fill").font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
    }

    // MARK: Add button

    private var addButton: some View {
        Button { isAddingItem = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add Item")
            }
            .font(.body.bold())
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    RunwayView(viewModel: DayViewModel())
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
