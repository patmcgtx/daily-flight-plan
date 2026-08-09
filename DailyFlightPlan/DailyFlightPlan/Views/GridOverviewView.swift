//
//  GridOverviewView.swift
//  DailyFlightPlan
//
//  Dashboard overview: all six sections visible as compact 2-column tiles.
//  Each tile shows a mini completion ring and the first few items.
//  Tap a tile to expand it into a detail sheet.
//
import SwiftUI
import SwiftData

struct GridOverviewView: View {

    var viewModel: DayViewModel

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @Environment(\.modelContext) private var modelContext
    @State private var expandedSection: DaySection?
    @State private var itemToEdit: PlanItem?
    @State private var isAddingItem = false

    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var dateItems: [PlanItem] {
        allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate) }
    }
    private var activeItems: [PlanItem] { dateItems.filter { $0.status != .canceled } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dateNavHeader.padding(.horizontal, 8).padding(.top, 4)

                overallProgress

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(DaySection.allCases) { section in
                        sectionTile(section)
                    }
                }
                .padding(.horizontal)

                let openItems = viewModel.anyTimeItems(from: activeItems)
                if !openItems.isEmpty {
                    openTile(openItems).padding(.horizontal)
                }

                Spacer(minLength: 80)
            }
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(item: $expandedSection) { section in sectionDetailSheet(section) }
        .sheet(isPresented: $isAddingItem) { ItemForm(date: viewModel.selectedDate) }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
    }

    // MARK: Date header

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

            VStack(spacing: 1) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption).foregroundStyle(.secondary)
                Text(viewModel.selectedDate, format: .dateTime.month(.abbreviated).day())
                    .font(.title2.bold()).monospacedDigit()
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
    }

    // MARK: Overall progress

    @ViewBuilder
    private var overallProgress: some View {
        let total = activeItems.count
        let done = activeItems.filter { $0.status == .completed }.count
        if total > 0 {
            HStack(spacing: 8) {
                ProgressRingView(
                    progress: Double(done) / Double(total),
                    completed: done,
                    total: total
                )
                Text("\(done) of \(total) complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    // MARK: Shared item preview row

    private func itemPreviewRow(_ item: PlanItem) -> some View {
        let icon = item.status == .completed ? "checkmark.circle.fill" : "circle"
        let iconColor: Color = item.status == .completed ? .accentColor : Color.secondary.opacity(0.4)
        let textColor: Color = item.status == .completed ? .secondary : .primary
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(iconColor)
            Text(item.title)
                .font(.caption)
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
    }

    // MARK: Section tile

    private func sectionTile(_ section: DaySection) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems)
        let deadlines = viewModel.deadlineRows(section, from: activeItems)
        let allSectionItems = pills + deadlines
        let completed = allSectionItems.filter { $0.status == .completed }.count
        let total = allSectionItems.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let isCurrent = viewModel.currentSection == section && viewModel.isToday
        let allDone = total > 0 && completed == total

        return Button { expandedSection = section } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Tile header
                HStack(alignment: .top, spacing: 8) {
                    Text(section.displayName)
                        .font(.headline)
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Circle()
                            .stroke(.secondary.opacity(0.15), lineWidth: 4)
                        if total > 0 {
                            Circle()
                                .trim(from: 0, to: pct)
                                .stroke(
                                    allDone ? Color.green : Color.accentColor,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(duration: 0.4), value: completed)
                        }
                        if allDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(width: 28, height: 28)
                }

                if isCurrent {
                    Label("NOW", systemImage: "circle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                        .labelStyle(CompactLabelStyle())
                }

                // Item previews
                if total == 0 {
                    Text("Nothing scheduled")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(allSectionItems.prefix(3))) { item in
                            itemPreviewRow(item)
                        }
                        if allSectionItems.count > 3 {
                            Text("+\(allSectionItems.count - 3) more")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer(minLength: 0)

                Text(section.timeRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isCurrent ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.25),
                                lineWidth: isCurrent ? 1.5 : 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Open tile (full width)

    private func openTile(_ items: [PlanItem]) -> some View {
        Button { /* no expand for open */ } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Open")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(items.prefix(4))) { item in
                        itemPreviewRow(item)
                    }
                    if items.count > 4 {
                        Text("+\(items.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Expanded section detail sheet

    private func sectionDetailSheet(_ section: DaySection) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems)
        let deadlines = viewModel.deadlineRows(section, from: activeItems)
        let allSectionItems = pills + deadlines
        let completed = allSectionItems.filter { $0.status == .completed }.count

        return NavigationStack {
            List {
                if allSectionItems.isEmpty {
                    Text("Nothing scheduled")
                        .foregroundStyle(.tertiary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(pills) { item in detailRow(item) }
                    ForEach(deadlines) { item in detailDeadlineRow(item) }
                }
            }
            .navigationTitle(section.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(completed)/\(allSectionItems.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { expandedSection = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(_ item: PlanItem) -> some View {
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
                .strikethrough(item.status == .completed)
                .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)

            Spacer()

            if item.isFlagged {
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
        }
    }

    private func detailDeadlineRow(_ item: PlanItem) -> some View {
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

            Spacer()

            if item.isFlagged {
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                item.status = .canceled
                try? modelContext.save()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }
        .contextMenu {
            Button { itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
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

// Compact label style that renders just the icon tightly
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 5))
            configuration.title
        }
    }
}

#Preview {
    GridOverviewView(viewModel: DayViewModel())
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
