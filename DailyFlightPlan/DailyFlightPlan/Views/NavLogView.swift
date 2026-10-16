//
//  NavLogView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

/// A fresh take on the Timeline tab: a standard `List` with one `Section` per calendar day,
/// defaulting to today scrolled to the *top* of the screen. Swipe actions (cancel/flag/defer/
/// delete) replace the old tab's context menu — this is the only screen that can delete an item.
struct NavLogView: View {

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false }, sort: \PlanItem.date)
    private var allItems: [PlanItem]

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = TimelineViewModel()
    @State private var itemToEdit: PlanItem? = nil

    /// Last date chosen via the date picker — purely to drive that control (label/"Today"
    /// disabled state); Nav Log itself has no single "current page", just a scroll position.
    @State private var pickedDate: Date = .now

    /// Blocks the past/future window-growth below until the initial mount has settled. On first
    /// appearance, every loaded day group (today ± 7 days) reports `onAppear` in one burst before
    /// the initial scroll-to-today runs, which — unguarded — reads each newly-grown-in earlier
    /// day as itself being "first" and grows the window again, cascading well past Today before
    /// things settle (confirmed: without this guard, the list opened in early October instead of
    /// mid-October).
    ///
    /// The initial scroll itself also has to wait on this same flag: an id-based `ScrollPosition`
    /// set declaratively at state-declaration time looked reliable in isolation, but silently
    /// stopped taking effect once this view also needed a `ScrollViewReader` for the date
    /// picker's scrollTo — the two apparently can't coexist on one `List`. `ScrollViewReader`
    /// alone is reliable for the picker (an already-settled, user-triggered scroll) and, once
    /// deferred past this same settle window, for the initial landing too.
    @State private var hasSettled = false

    private var groupedByDate: [(date: Date, items: [PlanItem])] {
        viewModel.groupedByDate(viewModel.loadedItems(from: allItems))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(groupedByDate, id: \.date) { group in
                        Section {
                            if group.items.isEmpty {
                                Text("Nothing planned")
                                    .font(PaperPlanStyle.mono(.subheadline))
                                    .foregroundStyle(PaperPlanStyle.muted)
                                    .listRowBackground(PaperRowBackground())
                                    .listRowSeparator(.hidden)
                            } else {
                                ForEach(viewModel.chronologicalOrder(for: group.items)) { item in
                                    NavLogItemRow(item: item) {
                                        itemToEdit = item
                                    }
                                    .listRowBackground(PaperRowBackground())
                                    .listRowSeparator(.hidden)
                                }
                            }
                        } header: {
                            dayHeader(for: group.date, items: group.items)
                        }
                        .id(group.date)
                        .onAppear {
                            guard hasSettled, groupedByDate.count > 1 else { return }
                            if group.date == groupedByDate.first?.date {
                                viewModel.pastDaysWindow += 7
                            }
                            if group.date == groupedByDate.last?.date {
                                viewModel.futureDaysWindow += 7
                            }
                        }
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #else
                // `.insetGrouped` combined with `.listRowSpacing` below made iOS treat each
                // gapped row as its own rounded "capsule" (automatic per-row corner rounding
                // once rows aren't visually contiguous), clipping `PaperRowBackground`'s square
                // `Rectangle`/stroke into a pill shape. `.plain` has no such grouping chrome, so
                // the row background renders with the flat square corners it's actually drawn
                // with — verified this didn't regress the settle-guarded scroll-to-today/
                // date-picker navigation, which doesn't depend on list style.
                .listStyle(.plain)
                #endif
                // Rows draw their own square-cornered border below (`PaperRowBackground`), so the
                // system separator is hidden and a small gap is added instead — reads as a stack
                // of flat-bordered cards, matching the Flight tab's look, rather than native
                // List chrome.
                .listRowSpacing(6)
                .scrollContentBackground(.hidden)
                .background { PaperPlanStyle.background.ignoresSafeArea() }
                .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
                // No title text — matches the Flight tab, which also has no `.navigationTitle`
                // and relies entirely on its toolbar; Nav Log is expected to grow the same full
                // toolbar eventually, making a placeholder title redundant until then.
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .trailingBar) {
                        DatePickerToolbarButton(
                            selectedDate: Binding(
                                get: { pickedDate },
                                set: { newDate in goToDate(newDate, proxy: proxy) }
                            ),
                            isToday: Calendar.current.isDateInToday(pickedDate),
                            onSelectToday: { goToDate(.now, proxy: proxy) }
                        )
                    }
                }
                .task {
                    try? await Task.sleep(for: .milliseconds(300))
                    hasSettled = true
                    proxy.scrollTo(viewModel.today, anchor: .top)
                }
            }
        }
    }

    /// Day section header: a "Today"/"Tomorrow"/"Yesterday" badge (highlighter-yellow for Today,
    /// matching the Flight tab's day label), the bold mono weekday/date, and — for today and past
    /// days only, mirroring the Flight tab's completion box — a "completed/total" count. Below
    /// that, every day gets the same mock "flight number" (`PaperPlanStyle.flightNumber(for:)`)
    /// shown on the Flight tab's full-page header, shrunk to fit a compact list-section header.
    @ViewBuilder
    private func dayHeader(for date: Date, items: [PlanItem]) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isTomorrow = calendar.isDateInTomorrow(date)
        let isYesterday = calendar.isDateInYesterday(date)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if isToday || isTomorrow || isYesterday {
                    Text(isToday ? "Today" : isTomorrow ? "Tomorrow" : "Yesterday")
                        .font(PaperPlanStyle.mono(.caption, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(isToday ? PaperPlanStyle.inkOnHighlighter : PaperPlanStyle.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isToday ? PaperPlanStyle.highlighter : Color.clear)
                }
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(PaperPlanStyle.mono(.subheadline, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PaperPlanStyle.ink)
                Spacer()
                if date <= viewModel.today {
                    let completed = items.filter { $0.status == .completed }.count
                    Text("\(completed)/\(items.count) COMPLETE")
                        .font(PaperPlanStyle.mono(.caption2, weight: .bold))
                        .foregroundStyle(PaperPlanStyle.muted)
                }
            }
            Text("FLIGHT \(PaperPlanStyle.flightNumber(for: date))")
                .font(PaperPlanStyle.mono(.caption2))
                .foregroundStyle(PaperPlanStyle.muted.opacity(0.7))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(PaperPlanStyle.headerBackground)
    }

    /// Grows the loaded window to cover `date` if it isn't already loaded, then scrolls its
    /// section to the top — the picker's equivalent of Day/Paper Plan's "navigate(to:)".
    ///
    /// Uses `ScrollViewProxy.scrollTo`, not the `scrollPosition` binding above: that binding only
    /// proved reliable as a *declarative initial value* set before first render — mutating it
    /// later in response to a button tap silently did nothing in testing (today's button and a
    /// future-date pick both failed to scroll). `scrollTo` on an already-mounted, fully-settled
    /// list (which this always is, since it only fires from a user tap) doesn't have the
    /// initial-mount timing problems that made the same API unreliable for the startup case.
    private func goToDate(_ date: Date, proxy: ScrollViewProxy) {
        pickedDate = date
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let daysFromToday = calendar.dateComponents([.day], from: viewModel.today, to: day).day ?? 0
        if daysFromToday < 0 {
            viewModel.pastDaysWindow = max(viewModel.pastDaysWindow, -daysFromToday)
        } else if daysFromToday > 0 {
            viewModel.futureDaysWindow = max(viewModel.futureDaysWindow, daysFromToday)
        }
        Task {
            // Give a window-growth re-render (if `date` wasn't already loaded) a moment to land
            // before scrolling, so the target section actually exists in the list.
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(day, anchor: .top)
            }
        }
    }
}

// MARK: - Row

private struct NavLogItemRow: View {

    let item: PlanItem
    let onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 10) {
            checkboxButton
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(PaperPlanStyle.mono(.body, weight: .bold))
                        .textCase(.uppercase)
                        .strikethrough(item.status == .completed || item.status == .canceled, color: PaperPlanStyle.muted)
                        .foregroundStyle(
                            item.isFlagged
                                ? PaperPlanStyle.inkOnHighlighter
                                : (item.status == .canceled ? PaperPlanStyle.muted : PaperPlanStyle.ink)
                        )
                        .lineLimit(1)
                        .padding(.horizontal, item.isFlagged ? 3 : 0)
                        .background(item.isFlagged ? PaperPlanStyle.highlighter.opacity(0.8) : Color.clear)
                    if !item.notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(PaperPlanStyle.muted)
                    }
                    if item.isRecurring {
                        Image(systemName: "infinity")
                            .font(.caption2)
                            .foregroundStyle(PaperPlanStyle.muted)
                    }
                }
                if let deadline = item.deadline {
                    Text(deadline, format: .dateTime.hour().minute())
                        .font(PaperPlanStyle.mono(.caption))
                        .foregroundStyle(PaperPlanStyle.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
        }
        .swipeActions(edge: .leading) {
            Button {
                item.isFlagged.toggle()
                try? modelContext.save()
            } label: {
                Label(item.isFlagged ? "Unflag" : "Flag", systemImage: "flag")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            Button {
                item.status = .canceled
                try? modelContext.save()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .tint(.gray)
            Button {
                item.deferToTomorrow()
                try? modelContext.save()
            } label: {
                Label("Defer", systemImage: "arrowshape.turn.up.right")
            }
            .tint(.blue)
        }
    }

    @ViewBuilder
    private var checkboxButton: some View {
        Button {
            guard item.status != .canceled else { return }
            withAnimation(.spring(duration: 0.2)) {
                item.status = item.status == .completed ? .pending : .completed
                try? modelContext.save()
            }
        } label: {
            // Square, not circle — matches the Figma mock's plain checkbox glyph (Flight's
            // pill-based checkmark uses a circle instead; this list reads more like a paper form).
            switch item.status {
            case .completed:
                Image(systemName: "checkmark.square.fill")
                    .foregroundStyle(PaperPlanStyle.ink)
            case .canceled:
                Image(systemName: "xmark.square")
                    .foregroundStyle(PaperPlanStyle.muted)
            case .pending:
                Image(systemName: "square")
                    .foregroundStyle(PaperPlanStyle.border)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row background

/// A flat, square-cornered card — `PaperPlanStyle.surface` filled, `PaperPlanStyle.border`
/// stroked — standing in for the system's rounded `insetGrouped` row background, so each row
/// reads as one of the Flight tab's bordered paper cards instead of native `List` chrome.
private struct PaperRowBackground: View {
    var body: some View {
        Rectangle()
            .fill(PaperPlanStyle.surface)
            .overlay(Rectangle().stroke(PaperPlanStyle.border, lineWidth: 1))
    }
}

#if DEBUG

#Preview {
    NavLogView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}

#endif
