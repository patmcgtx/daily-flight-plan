//
//  RunwayView.swift
//  DailyFlightPlan
//
//  Infinite scroll timeline: ±180 days from today, flat checklist style.
//  Each day is a pinned-header section. Each time section has its own + button.
//  Filter, category, and theme state is shared with the Focus tab via @AppStorage.
//
import SwiftUI
import SwiftData

struct RunwayView: View {

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @Query(sort: \PlanCategory.name)
    private var allCategories: [PlanCategory]

    @AppStorage(AppStorageKeys.showFlaggedOnly.rawValue)
    private var showFlaggedOnly: Bool = false

    @AppStorage(AppStorageKeys.showCompleted.rawValue)
    private var showCompleted: Bool = false

    @AppStorage(AppStorageKeys.showRecurring.rawValue)
    private var showRecurring: Bool = true

    @AppStorage(AppStorageKeys.theme.rawValue)
    private var theme: DFPTheme = .cupertino

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

    @Environment(\.modelContext) private var modelContext

    @State private var addingToDate: Date? = nil
    @State private var addingToSection: DaySection? = nil
    @State private var itemToEdit: PlanItem? = nil
    @State private var showCategorySelector = false
    @State private var isShowingCategoriesEdit = false

    private var isFilterActive: Bool {
        showFlaggedOnly || showCompleted || !showRecurring
    }

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var dates: [Date] {
        let cal = Calendar.current
        return (-180...180).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(dates, id: \.self) { date in
                            Section {
                                dayContent(for: date)
                            } header: {
                                dayHeader(for: date)
                            }
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo(today, anchor: .top)
                }
                .navigationTitle("Runway")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation { proxy.scrollTo(today, anchor: .top) }
                        } label: {
                            Image(systemName: "scope")
                        }
                        .accessibilityLabel("Go to Today")
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Toggle(isOn: $showFlaggedOnly) {
                                Label("Flagged Only", systemImage: "flag.fill")
                            }
                            Toggle(isOn: $showCompleted) {
                                Label("Show Completed", systemImage: "checkmark")
                            }
                            Toggle(isOn: $showRecurring) {
                                Label("Routines", systemImage: "infinity")
                            }
                        } label: {
                            Image(systemName: isFilterActive
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle")
                                .foregroundStyle(isFilterActive ? Color.accentColor : Color.primary)
                        }
                        .accessibilityLabel("Filters")

                        Button { showCategorySelector = true } label: {
                            Image(systemName: "tag")
                        }
                        .accessibilityLabel("Filter by Category")

                        Menu {
                            ForEach(DFPTheme.allCases) { option in
                                Button { theme = option } label: {
                                    Label(option.localizedName, systemImage: option.menuIconName)
                                }
                            }
                        } label: {
                            Image(systemName: theme.menuIconName)
                                .foregroundStyle(theme == .cupertino ? Color.primary : Color.accentColor)
                        }
                        .accessibilityLabel("Theme")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            addingToDate = today
                            addingToSection = nil
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Item")
                    }
                }
            }
        }
        .environment(\.editItem) { item in itemToEdit = item }
        .sheet(isPresented: Binding(
            get: { addingToDate != nil },
            set: { if !$0 { addingToDate = nil; addingToSection = nil } }
        )) {
            if let date = addingToDate {
                ItemForm(date: date, section: addingToSection)
            }
        }
        .sheet(item: $itemToEdit) { item in ItemForm(item: item) }
        .sheet(isPresented: $showCategorySelector) { categorySelectorSheet }
        .sheet(isPresented: $isShowingCategoriesEdit) { CategoriesEditView() }
    }

    // MARK: Category selector sheet

    private var categorySelectorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Category")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            if allCategories.isEmpty {
                Text("No categories yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allCategories) { category in
                            CategoryCapsule(category: category)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Button("Manage Categories") {
                showCategorySelector = false
                isShowingCategoriesEdit = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .presentationDetents([.height(160)])
        .presentationDragIndicator(.visible)
    }

    // MARK: Day header (sticky)

    private func dayHeader(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isPast = date < today
        return HStack(spacing: 8) {
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.subheadline.bold())
                .foregroundStyle(isToday ? Color.accentColor : isPast ? Color.secondary : Color.primary)
            if isToday {
                Text("TODAY")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.background)
        .id(date)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: Day content

    @ViewBuilder
    private func dayContent(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > today
        let items = itemsForDate(date)
        let currentSection: DaySection? = isToday ? DaySection.containing(.now) : nil

        ForEach(DaySection.allCases) { section in
            let pills = sectionPills(section, from: items)
            let deadlines = deadlineItems(section, from: items)
            if !pills.isEmpty || !deadlines.isEmpty || isToday || isFuture {
                runwaySection(
                    section, date: date,
                    pills: pills, deadlines: deadlines,
                    isCurrent: currentSection == section
                )
            }
        }

        let openItems = anyTimeItems(from: items)
        if !openItems.isEmpty {
            openBlock(items: openItems, date: date)
        }

        // Bottom spacer between days
        Divider()
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    // MARK: Item filtering

    private func itemsForDate(_ date: Date) -> [PlanItem] {
        let filtered = allItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
            && (showCompleted || ($0.status != .completed && $0.status != .canceled))
            && (!showFlaggedOnly || $0.isFlagged)
            && (showRecurring || !$0.isRecurring)
        }
        return categorySelectionService?.filterItems(filtered) ?? filtered
    }

    private func sectionPills(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.daySection == section && $0.deadline == nil }
    }

    private func deadlineItems(_ section: DaySection, from items: [PlanItem]) -> [PlanItem] {
        items.filter {
            $0.deadline != nil && $0.daySection == nil &&
            DaySection.containing($0.deadline!) == section
        }.sorted { ($0.deadline ?? .distantPast) < ($1.deadline ?? .distantPast) }
    }

    private func anyTimeItems(from items: [PlanItem]) -> [PlanItem] {
        items.filter { $0.daySection == nil && $0.deadline == nil }
    }

    // MARK: Section block

    @ViewBuilder
    private func runwaySection(
        _ section: DaySection, date: Date,
        pills: [PlanItem], deadlines: [PlanItem],
        isCurrent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section divider row
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isCurrent ? Color.accentColor : Color.clear)
                    .frame(width: 3)

                HStack(spacing: 6) {
                    if isCurrent {
                        Circle().fill(.red).frame(width: 5, height: 5)
                    }
                    Text(section.displayName.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                        .kerning(1.1)
                    Text(section.timeRangeLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button {
                        addingToDate = date
                        addingToSection = section
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)

            // Items
            if pills.isEmpty && deadlines.isEmpty {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isCurrent ? Color.accentColor.opacity(0.25) : Color.clear)
                        .frame(width: 3)
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                        .padding(.leading, 16)
                        .padding(.vertical, 4)
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(isCurrent ? Color.accentColor.opacity(0.25) : Color.clear)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(pills) { item in checkRow(item) }
                        ForEach(deadlines) { item in deadlineCheckRow(item) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func openBlock(items: [PlanItem], date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.clear).frame(width: 3)
                HStack(spacing: 6) {
                    Text("OPEN")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .kerning(1.1)
                    Spacer()
                    Button {
                        addingToDate = date
                        addingToSection = nil
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)

            HStack(alignment: .top, spacing: 0) {
                Rectangle().fill(Color.clear).frame(width: 3)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in checkRow(item) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
                    .foregroundStyle(item.status == .completed
                        ? Color.accentColor
                        : Color.secondary.opacity(0.4))
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
                    .foregroundStyle(item.status == .completed
                        ? Color.accentColor
                        : Color.secondary.opacity(0.4))
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
}

#Preview {
    RunwayView()
        .injectMockServices()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
