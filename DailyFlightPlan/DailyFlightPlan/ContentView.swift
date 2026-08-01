//
//  ContentView.swift
//  DailyFlightPlan
//
//  Created by Patrick McGonigle on 7/24/26.
//

import SwiftUI
import SwiftData

// MARK: - Content View

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var selectedCategory: TaskCategory? = nil
    @State private var showFilters = false
    @State private var filterStarred = false
    @State private var filterCompleted = false
    @State private var filterRecurring = false

    @Query private var allTasks: [TaskItem]

    private var calendar: Calendar { .current }

    private var tasksForDate: [TaskItem] {
        allTasks.filter { calendar.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
    }

    private var filteredTasks: [TaskItem] {
        tasksForDate.filter { task in
            guard !task.isCancelled else { return false }
            if let cat = selectedCategory, task.category != cat { return false }
            if filterStarred && !task.isStarred { return false }
            if filterRecurring && !task.isRecurring { return false }
            if !filterCompleted && task.isCompleted { return false }
            return true
        }
    }

    private var completedCount: Int { tasksForDate.filter { $0.isCompleted }.count }
    private var totalCount: Int { tasksForDate.filter { !$0.isCancelled }.count }
    private var isToday: Bool { calendar.isDateInToday(selectedDate) }

    private var currentTimeBlock: TimeBlock? {
        guard isToday else { return nil }
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .midday
        case 17..<22: return .evening
        default: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            categorySelector
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(TimeBlock.scheduled, id: \.self) { block in
                        TimeBlockSectionView(
                            block: block,
                            tasks: filteredTasks.filter { $0.timeBlock == block },
                            isCurrentBlock: currentTimeBlock == block,
                            onComplete: completeTask,
                            onCancel: cancelTask,
                            onDelete: deleteTask
                        )
                        Divider()
                    }
                    AnytimeSectionView(
                        tasks: filteredTasks.filter { $0.timeBlock == .anytime },
                        onComplete: completeTask,
                        onCancel: cancelTask,
                        onDelete: deleteTask
                    )
                }
                .padding(.bottom, 16)
            }
            Divider()
            bottomNavigation
        }
        .sheet(isPresented: $showFilters) {
            FilterPanelView(
                filterStarred: $filterStarred,
                filterCompleted: $filterCompleted,
                filterRecurring: $filterRecurring
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { showFilters.toggle() } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(selectedDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.title)
                    .fontWeight(.bold)
            }

            Spacer()

            if totalCount > 0 {
                CompletionStatusView(completed: completedCount, total: totalCount)
            }

            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Category Selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryPill(title: "All", color: Color(.systemGray), isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(TaskCategory.allCases, id: \.self) { cat in
                    CategoryPill(title: cat.rawValue, color: cat.color, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: Bottom Navigation

    private var bottomNavigation: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button("Today") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = Date()
                }
            }
            .font(.headline)
            .foregroundStyle(isToday ? Color.secondary : .blue)
            .disabled(isToday)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: Actions

    private func completeTask(_ task: TaskItem) {
        withAnimation { task.isCompleted.toggle() }
    }

    private func cancelTask(_ task: TaskItem) {
        withAnimation { task.isCancelled = true }
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation { modelContext.delete(task) }
    }
}

// MARK: - Completion Status

struct CompletionStatusView: View {
    let completed: Int
    let total: Int

    var body: some View {
        if total <= 8 {
            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i < completed ? Color.green : Color.secondary.opacity(0.25))
                        .frame(width: 7, height: 7)
                }
            }
        } else {
            Text("\(completed)/\(total)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Block Section

struct TimeBlockSectionView: View {
    let block: TimeBlock
    let tasks: [TaskItem]
    let isCurrentBlock: Bool
    let onComplete: (TaskItem) -> Void
    let onCancel: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void

    @State private var isExpanded = true

    private var sortedTasks: [TaskItem] {
        tasks.sorted { a, b in
            switch (a.specificTime, b.specificTime) {
            case (let t1?, let t2?): return t1 < t2
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return a.title < b.title
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: block.symbolName)
                        .foregroundStyle(block.accentColor)
                        .frame(width: 20)
                    Text(block.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if isCurrentBlock {
                        Text("Now")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if !tasks.isEmpty {
                        Text("\(tasks.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if sortedTasks.isEmpty {
                    Text("No tasks scheduled")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 52)
                        .padding(.vertical, 10)
                } else {
                    ForEach(Array(sortedTasks.enumerated()), id: \.element.persistentModelID) { index, task in
                        TaskRowView(task: task, onComplete: onComplete, onCancel: onCancel, onDelete: onDelete)
                        if index < sortedTasks.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Anytime Section

struct AnytimeSectionView: View {
    let tasks: [TaskItem]
    let onComplete: (TaskItem) -> Void
    let onCancel: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void

    private var sortedTasks: [TaskItem] {
        tasks.sorted { $0.title < $1.title }
    }

    var body: some View {
        if !tasks.isEmpty {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: TimeBlock.anytime.symbolName)
                        .foregroundStyle(TimeBlock.anytime.accentColor)
                        .frame(width: 20)
                    Text("Any Time Today")
                        .font(.headline)
                    Spacer()
                    Text("\(tasks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ForEach(Array(sortedTasks.enumerated()), id: \.element.persistentModelID) { index, task in
                    TaskRowView(task: task, onComplete: onComplete, onCancel: onCancel, onDelete: onDelete)
                    if index < sortedTasks.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: TaskItem
    let onComplete: (TaskItem) -> Void
    let onCancel: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { onComplete(task) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .frame(width: 28)

            RoundedRectangle(cornerRadius: 2)
                .fill(task.category.color)
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    if task.isCalendarEvent {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if task.isRecurring {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if task.isStarred {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if task.urgencyLevel > 0 {
                        Text(String(repeating: "!", count: min(task.urgencyLevel, 3)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                }

                if let time = task.specificTime {
                    Text(time, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete(task) } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { onCancel(task) } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button { onComplete(task) } label: {
                Label(
                    task.isCompleted ? "Undo" : "Complete",
                    systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(.green)
        }
    }
}

// MARK: - Filter Panel

struct FilterPanelView: View {
    @Binding var filterStarred: Bool
    @Binding var filterCompleted: Bool
    @Binding var filterRecurring: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Show Only") {
                    Toggle("Starred Items", isOn: $filterStarred)
                    Toggle("Recurring Items", isOn: $filterRecurring)
                }
                Section("Visibility") {
                    Toggle("Show Completed", isOn: $filterCompleted)
                }
            }
            .navigationTitle("Filters")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskItem.self, configurations: config)
    let ctx = container.mainContext

    let today = Date()
    let cal = Calendar.current

    func time(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    let tasks: [TaskItem] = [
        TaskItem(title: "Brunch", category: .personal, scheduledDate: today, timeBlock: .morning),
        TaskItem(title: "Walk", category: .health, scheduledDate: today, timeBlock: .morning, isRecurring: true),
        TaskItem(title: "Breathe", category: .health, scheduledDate: today, timeBlock: .morning, isRecurring: true),
        TaskItem(title: "Standup", category: .work, scheduledDate: today, specificTime: time(8, 30), timeBlock: .morning, isCalendarEvent: true),
        TaskItem(title: "Call Stan", category: .work, scheduledDate: today, specificTime: time(10), timeBlock: .morning),
        TaskItem(title: "Lunch - Denisa", category: .personal, scheduledDate: today, specificTime: time(12, 30), timeBlock: .midday),
        TaskItem(title: "Meditate", category: .health, scheduledDate: today, timeBlock: .midday, isRecurring: true),
        TaskItem(title: "1:00 check-in", category: .work, scheduledDate: today, specificTime: time(13), timeBlock: .midday, isCalendarEvent: true),
        TaskItem(title: "Call Mom", category: .personal, scheduledDate: today, timeBlock: .anytime, isStarred: true),
        TaskItem(title: "Get Cash", category: .finance, scheduledDate: today, timeBlock: .anytime),
    ]

    for task in tasks { ctx.insert(task) }

    return ContentView()
        .modelContainer(container)
}
