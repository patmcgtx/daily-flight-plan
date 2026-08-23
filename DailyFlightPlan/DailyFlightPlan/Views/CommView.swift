//
//  CommView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Item creation types

struct ItemSpec: Sendable {
    var title: String
    var section: DaySection?
    var isRecurring: Bool
    var weekdays: [Locale.Weekday]
    var isForTomorrow: Bool
}

actor ItemCreationQueue {
    private(set) var items: [ItemSpec] = []
    func enqueue(_ item: ItemSpec) { items.append(item) }
    func drain() -> [ItemSpec] {
        let result = items
        items = []
        return result
    }
}

struct CreateItemTool: Tool {
    let name = "createPlanItem"
    let description = "Create a new item in the user's daily plan. Call this when the user asks to add a task, habit, or reminder."

    @Generable
    struct Arguments {
        @Guide(description: "Clear title for the new plan item")
        var title: String

        @Guide(description: "Time segment: firstThing, morning, midday, afternoon, evening, bedtime, or open")
        var section: String

        @Guide(description: "True if this is a recurring daily habit or routine")
        var isRecurring: Bool

        @Guide(description: "Schedule for recurring items: everyday, weekdays, weekends, or comma-separated abbreviations (mon, tue, wed, thu, fri, sat, sun). Empty string for non-recurring items.")
        var schedule: String

        @Guide(description: "True to add the item to tomorrow's plan instead of today's")
        var isTomorrow: Bool
    }

    let queue: ItemCreationQueue

    func call(arguments: Arguments) async throws -> String {
        let section = commDaySection(from: arguments.section)
        let recurring = arguments.isRecurring
        let weekdays = recurring ? commWeekdays(from: arguments.schedule) : []
        let spec = ItemSpec(
            title: arguments.title.trimmingCharacters(in: .whitespacesAndNewlines),
            section: section,
            isRecurring: recurring && !weekdays.isEmpty,
            weekdays: weekdays,
            isForTomorrow: arguments.isTomorrow
        )
        await queue.enqueue(spec)
        let day = arguments.isTomorrow ? "tomorrow" : "today"
        let sectionDesc = section.map { " in \($0.displayName)" } ?? ""
        return "Added '\(spec.title)'\(sectionDesc) for \(day)."
    }
}

private func commDaySection(from string: String) -> DaySection? {
    switch string.lowercased().trimmingCharacters(in: .whitespaces) {
    case "firstthing", "first_thing", "first thing": return .firstThing
    case "morning": return .morning
    case "midday", "noon", "lunch": return .midday
    case "afternoon": return .afternoon
    case "evening": return .evening
    case "bedtime", "night": return .bedtime
    default: return nil
    }
}

private func commWeekdays(from schedule: String) -> [Locale.Weekday] {
    let s = schedule.lowercased().trimmingCharacters(in: .whitespaces)
    switch s {
    case "everyday", "daily", "every day":
        return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    case "weekdays":
        return [.monday, .tuesday, .wednesday, .thursday, .friday]
    case "weekends":
        return [.saturday, .sunday]
    default:
        let map: [String: Locale.Weekday] = [
            "mon": .monday, "tue": .tuesday, "wed": .wednesday,
            "thu": .thursday, "fri": .friday, "sat": .saturday, "sun": .sunday
        ]
        return s.components(separatedBy: ",").compactMap { map[$0.trimmingCharacters(in: .whitespaces)] }
    }
}

// MARK: - ViewModel

@Observable @MainActor
final class CommViewModel {

    struct ChatMessage: Identifiable {
        let id = UUID()
        enum Role { case user, assistant }
        let role: Role
        var content: String
        var isStreaming: Bool = false
    }

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String? = nil
    private(set) var sessionReady = false
    var onItemsCreated: (([ItemSpec]) -> Void)?

    private var session: LanguageModelSession?
    private let itemQueue = ItemCreationQueue()

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isGenerating && sessionReady
    }

    func buildSession(allItems: [PlanItem], templates: [PlanItem]) {
        let context = buildContext(allItems: allItems, templates: templates)
        let tool = CreateItemTool(queue: itemQueue)
        session = LanguageModelSession(
            tools: [tool],
            instructions: """
                You are a concise daily planning assistant for the Daily Flight Plan app. \
                Answer questions about the user's plan briefly and conversationally — one to three sentences. \
                Do not repeat the full plan back unless directly asked. \
                When the user asks to add, create, or schedule an item, call the createPlanItem tool. \
                Current plan:\n\(context)
                """
        )
        sessionReady = true
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        let assistantIdx = messages.count
        messages.append(ChatMessage(role: .assistant, content: "", isStreaming: true))
        isGenerating = true
        errorMessage = nil

        do {
            let stream = session.streamResponse(to: text)
            for try await snapshot in stream {
                messages[assistantIdx].content = snapshot.content
            }
            messages[assistantIdx].isStreaming = false
            let created = await itemQueue.drain()
            if !created.isEmpty { onItemsCreated?(created) }
        } catch {
            messages[assistantIdx].content = "Sorry, something went wrong. Please try again."
            messages[assistantIdx].isStreaming = false
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    func reset(allItems: [PlanItem], templates: [PlanItem]) {
        messages = []
        errorMessage = nil
        buildSession(allItems: allItems, templates: templates)
    }

    // MARK: - Context building

    private func buildContext(allItems: [PlanItem], templates: [PlanItem]) -> String {
        let now = Date.now
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let weekdayMap: [Int: Locale.Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]

        var lines: [String] = [
            "Date/time: \(now.formatted(date: .complete, time: .shortened))",
            ""
        ]

        // MARK: Recent history (7 days back, oldest first, compact summaries)
        let pastDays = (1...7).compactMap { cal.date(byAdding: .day, value: -$0, to: todayStart) }.reversed()
        lines.append("RECENT HISTORY (last 7 days):")
        var hadHistory = false
        for dayStart in pastDays {
            let dayItems = allItems.filter { cal.isDate($0.date, inSameDayAs: dayStart) }
            guard !dayItems.isEmpty else { continue }
            hadHistory = true
            let completed = dayItems.filter { $0.status == .completed }.count
            let canceled = dayItems.filter { $0.status == .canceled }.count
            let pending = dayItems.filter { $0.status == .pending }.count
            let label = dayStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            lines.append("  \(label): \(completed) completed, \(canceled) canceled, \(pending) pending (\(dayItems.count) total)")
        }
        if !hadHistory { lines.append("  (no history)") }

        // MARK: Today (full detail)
        let todayItems = allItems.filter { cal.isDateInToday($0.date) }
        lines.append("")
        lines.append("TODAY:")
        if todayItems.isEmpty {
            lines.append("  (nothing planned)")
        } else {
            let completed = todayItems.filter { $0.status == .completed }.count
            let canceled = todayItems.filter { $0.status == .canceled }.count
            let pending = todayItems.filter { $0.status == .pending }.count
            lines.append("  Summary: \(completed) completed, \(canceled) canceled, \(pending) pending (\(todayItems.count) total)")
            for section in DaySection.allCases {
                let inSection = todayItems.filter { $0.daySection == section }
                let atTime = todayItems.filter {
                    $0.daySection == nil && $0.deadline != nil
                        && DaySection.containing($0.deadline!) == section
                }
                let all = (inSection + atTime).sorted {
                    ($0.deadline ?? .distantPast) < ($1.deadline ?? .distantPast)
                }
                guard !all.isEmpty else { continue }
                lines.append("  \(section.displayName):")
                for item in all {
                    let icon = item.status == .completed ? "✓" : item.status == .canceled ? "✗" : "○"
                    var row = "    \(icon) \(item.title)"
                    if let d = item.deadline {
                        row += " (\(d.formatted(date: .omitted, time: .shortened)))"
                    }
                    lines.append(row)
                }
            }
            let open = todayItems.filter { $0.daySection == nil && $0.deadline == nil }
            if !open.isEmpty {
                lines.append("  Open:")
                for item in open {
                    let icon = item.status == .completed ? "✓" : item.status == .canceled ? "✗" : "○"
                    lines.append("    \(icon) \(item.title)")
                }
            }
        }

        // MARK: Upcoming (tomorrow through +7, ghost projections from templates)
        for offset in 1...7 {
            guard let dayStart = cal.date(byAdding: .day, value: offset, to: todayStart) else { continue }
            let dayItems = allItems.filter { cal.isDate($0.date, inSameDayAs: dayStart) }
            let wd = weekdayMap[cal.component(.weekday, from: dayStart)]
            var ghosted: [PlanItem] = []
            if let wd {
                ghosted = templates
                    .filter { $0.recurringWeekdays.contains(wd) }
                    .filter { t in !dayItems.contains { $0.title == t.title && $0.daySection == t.daySection } }
            }
            let allForDay = (dayItems + ghosted).sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
            let header = offset == 1
                ? "TOMORROW (\(dayStart.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))):"
                : "\(dayStart.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()):"
            lines.append("")
            lines.append(header)
            if allForDay.isEmpty {
                lines.append("  (nothing planned)")
            } else {
                for item in allForDay {
                    var row = "  ○ \(item.title)"
                    if let s = item.daySection { row += " [\(s.displayName)]" }
                    lines.append(row)
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - CommView

struct CommView: View {

    @State private var viewModel = CommViewModel()
    @FocusState private var inputFocused: Bool
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == true })
    private var templates: [PlanItem]


    var body: some View {
        NavigationStack {
            Group {
                if SystemLanguageModel.default.isAvailable {
                    chatView
                } else {
                    unavailableView
                }
            }
            .navigationTitle("Comm")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") { inputFocused = false }
                    Spacer()
                }
            }
        }
        .onAppear {
            viewModel.onItemsCreated = { specs in
                let cal = Calendar.current
                let today = cal.startOfDay(for: .now)
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
                for spec in specs {
                    let date = spec.isForTomorrow ? tomorrow : today
                    if spec.isRecurring && !spec.weekdays.isEmpty {
                        modelContext.insert(PlanItem(
                            title: spec.title,
                            date: date,
                            daySection: spec.section,
                            recurringWeekdays: spec.weekdays,
                            isTemplate: true
                        ))
                    } else {
                        modelContext.insert(PlanItem(
                            title: spec.title,
                            date: date,
                            daySection: spec.section
                        ))
                    }
                }
                try? modelContext.save()
            }
            if !viewModel.sessionReady {
                viewModel.buildSession(allItems: allItems, templates: templates)
            }
        }
    }

    // MARK: Chat view

    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            emptyState
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        }
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
            inputBar
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Ask about your plan")
                .font(.headline)
            VStack(spacing: 4) {
                Text("\"What did I get done this week?\"")
                Text("\"What's left for today?\"")
                Text("\"What do I have on Thursday?\"")
                Text("\"Add a yoga class Friday morning\"")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            Text("Knows your last 7 days and next 7 days. Runs on-device — your data stays private.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your plan…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    guard viewModel.canSend else { return }
                    Task { await viewModel.send() }
                }

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(viewModel.canSend ? Color.accentColor : Color.secondary)
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "On-Device AI Required",
            systemImage: "apple.intelligence",
            description: Text("Comm requires Apple Intelligence, which isn't available on this device.")
        )
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: CommViewModel.ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user { Spacer(minLength: 48) }
            Group {
                if message.isStreaming && message.content.isEmpty {
                    TypingIndicator()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                } else {
                    assistantText(message)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                        .textSelection(.enabled)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.role == .user ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial))
            )
            if message.role == .assistant { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    @ViewBuilder
    private func assistantText(_ message: CommViewModel.ChatMessage) -> some View {
        if message.role == .assistant,
           let attributed = try? AttributedString(
               markdown: message.content,
               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
           ) {
            Text(attributed)
        } else {
            Text(message.content)
        }
    }
}

// MARK: - TypingIndicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(Color.secondary)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

#Preview {
    CommView()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
