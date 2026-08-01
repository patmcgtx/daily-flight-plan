//
//  DayView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import Flow

struct DayView: View {

    @State private var viewModel = DayViewModel()

    @Query private var allItems: [PlanItem]

    @AppStorage(AppStorageKeys.theme.rawValue)
    private var theme: DFPTheme = .cupertino

    private var itemsForSelectedDate: [PlanItem] {
        allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: viewModel.selectedDate)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            dayScrollView
        }
    }

    // MARK: Sticky header

    private var headerView: some View {
        VStack(spacing: 8) {
            dateNavRow
            filterRow
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var dateNavRow: some View {
        HStack(spacing: 8) {
            Button { viewModel.goToYesterday() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 20)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Previous Day")

            Spacer()

            VStack(spacing: 1) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(viewModel.selectedDate, format: .dateTime.month(.abbreviated).day())
                        .font(.title2.bold())
                    // Date picker placeholder (not yet implemented)
                    Button { } label: {
                        Image(systemName: "calendar.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select Date")
                }
            }

            Spacer()

            HStack(spacing: 8) {
                progressRingPlaceholder
                Button { } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Settings")
                Menu {
                    ForEach(DFPTheme.allCases) { option in
                        Button { theme = option } label: {
                            Label(option.localizedName, systemImage: option.menuIconName)
                        }
                    }
                } label: {
                    Image(systemName: theme.menuIconName)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Theme")
                Button { viewModel.goToTomorrow() } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 20)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Next Day")
            }
        }
        .padding(.horizontal)
    }

    private var progressRingPlaceholder: some View {
        Circle()
            .trim(from: 0, to: 0.6)
            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .foregroundStyle(.secondary.opacity(0.3))
            .frame(width: 26, height: 26)
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterToggle("Flagged", icon: "star.fill")
                filterToggle("Done", icon: "checkmark")
                filterToggle("Recurring", icon: "infinity")
                // Category capsules come in Phase 6
            }
            .padding(.horizontal)
        }
    }

    private func filterToggle(_ title: String, icon: String) -> some View {
        // Stubs for Phase 6 — no action yet
        Button { } label: {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
    }

    // MARK: Scrollable day content

    private var dayScrollView: some View {
        let selectedDateItems = itemsForSelectedDate
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(DaySection.allCases) { section in
                        DaySectionView(
                            section: section,
                            sectionPills: viewModel.sectionPills(section, from: selectedDateItems),
                            deadlineRows: viewModel.deadlineRows(section, from: selectedDateItems),
                            showNowBar: viewModel.currentSection == section,
                            isCollapsed: viewModel.isCollapsed(section),
                            onToggle: {
                                withAnimation(.spring(duration: 0.25)) {
                                    viewModel.toggleCollapsed(section)
                                }
                            }
                        )
                        .id(section)
                    }

                    anyTimeSection(items: selectedDateItems)
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .safeAreaInset(edge: .bottom) {
                addButton
            }
            .onAppear {
                if let current = viewModel.currentSection {
                    proxy.scrollTo(current, anchor: .top)
                }
            }
        }
    }

    // MARK: Any time section

    private func anyTimeSection(items: [PlanItem]) -> some View {
        let anyTimeItems = viewModel.anyTimeItems(from: items)
        return Group {
            if !anyTimeItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Any Time")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    HFlow(itemSpacing: 8, rowSpacing: 8) {
                        ForEach(anyTimeItems) { item in
                            ItemPillView(item: item)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: Add button

    private var addButton: some View {
        Button { } label: {
            Label("Add Item", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
        }
        .buttonStyle(.glass)
        .padding(.bottom, 12)
    }
}

#Preview {
    DayView()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
