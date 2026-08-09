//
//  CardDeckView.swift
//  DailyFlightPlan
//
//  Section spotlight: one section per swipeable page.
//  Each card shows the section name large, a per-section completion ring,
//  and a plain item list. Swipe to move between sections.
//
import SwiftUI
import SwiftData

struct CardDeckView: View {

    var viewModel: DayViewModel

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: DaySection = .morning
    @State private var itemToEdit: PlanItem?
    @State private var isAddingItem = false

    private var dateItems: [PlanItem] {
        allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate) }
    }
    private var activeItems: [PlanItem] { dateItems.filter { $0.status != .canceled } }

    var body: some View {
        VStack(spacing: 0) {
            dateNavHeader

            TabView(selection: $selectedSection) {
                ForEach(DaySection.allCases) { section in
                    sectionCard(section)
                        .tag(section)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .onAppear { jumpToCurrentSection() }
        .onChange(of: viewModel.selectedDate) { _, _ in jumpToCurrentSection() }
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(isPresented: $isAddingItem) { ItemForm(date: viewModel.selectedDate) }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
    }

    private func jumpToCurrentSection() {
        if let current = viewModel.currentSection {
            selectedSection = current
        }
    }

    // MARK: Date header

    private var dateNavHeader: some View {
        HStack {
            Button { withAnimation(.easeInOut(duration: 0.25)) { viewModel.goToYesterday() } } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
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
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    // MARK: Section card

    private func sectionCard(_ section: DaySection) -> some View {
        let pills = viewModel.sectionPills(section, from: activeItems)
        let deadlines = viewModel.deadlineRows(section, from: activeItems)
        let allSectionItems = pills + deadlines
        let completed = allSectionItems.filter { $0.status == .completed }.count
        let total = allSectionItems.count
        let pct = total > 0 ? Double(completed) / Double(total) : 0
        let isCurrent = viewModel.currentSection == section && viewModel.isToday
        let allDone = total > 0 && completed == total

        return VStack(alignment: .leading, spacing: 0) {
            // Card header
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.displayName)
                            .font(.largeTitle.bold())
                            .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)

                        HStack(spacing: 5) {
                            if isCurrent {
                                Circle().fill(.red).frame(width: 6, height: 6)
                                Text("NOW  ·")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                            }
                            Text(section.timeRangeLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Section completion ring
                    ZStack {
                        Circle()
                            .stroke(.secondary.opacity(0.15), lineWidth: 6)
                        if total > 0 {
                            Circle()
                                .trim(from: 0, to: pct)
                                .stroke(
                                    allDone ? Color.green : Color.accentColor,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(duration: 0.4), value: completed)
                        }
                        if allDone {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        } else {
                            Text(total > 0 ? "\(completed)/\(total)" : "—")
                                .font(.caption2.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 56, height: 56)
                }

                Button { isAddingItem = true } label: {
                    Label("Add to \(section.displayName)", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(.quaternary.opacity(0.4))

            Divider()

            // Items
            if allSectionItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(pills) { item in
                            cardRow(item)
                            if item.id != pills.last?.id || !deadlines.isEmpty {
                                Divider().padding(.leading, 54)
                            }
                        }
                        ForEach(deadlines) { item in
                            cardDeadlineRow(item)
                            if item.id != deadlines.last?.id {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "moon.zzz")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Nothing scheduled")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Row types

    private func cardRow(_ item: PlanItem) -> some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if item.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.body)
                .strikethrough(item.status == .completed)
                .foregroundStyle(item.status == .completed ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if item.isFlagged {
                    Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
                }
                if item.isRecurring {
                    Image(systemName: "infinity").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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

    private func cardDeadlineRow(_ item: PlanItem) -> some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    item.status = item.status == .completed ? .pending : .completed
                    try? modelContext.save()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            item.status == .completed ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if item.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
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
                Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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
}

#Preview {
    CardDeckView(viewModel: DayViewModel())
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
