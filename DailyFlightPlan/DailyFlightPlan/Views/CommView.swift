//
//  CommView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import FoundationModels

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

    private var session: LanguageModelSession?

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isGenerating && sessionReady
    }

    func buildSession(todayItems: [PlanItem], tomorrowItems: [PlanItem], templates: [PlanItem]) {
        let context = buildContext(todayItems: todayItems, tomorrowItems: tomorrowItems, templates: templates)
        session = LanguageModelSession(instructions: """
            You are a concise daily planning assistant for the Daily Flight Plan app. \
            The user will ask questions about their plan for today and tomorrow. \
            Answer briefly and conversationally — one to three sentences. \
            Do not repeat the full plan back unless directly asked. \
            Current plan:\n\(context)
            """)
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
        } catch {
            messages[assistantIdx].content = "Sorry, something went wrong. Please try again."
            messages[assistantIdx].isStreaming = false
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    func reset(todayItems: [PlanItem], tomorrowItems: [PlanItem], templates: [PlanItem]) {
        messages = []
        errorMessage = nil
        buildSession(todayItems: todayItems, tomorrowItems: tomorrowItems, templates: templates)
    }

    // MARK: - Context building

    private func buildContext(todayItems: [PlanItem], tomorrowItems: [PlanItem], templates: [PlanItem]) -> String {
        let now = Date.now
        let cal = Calendar.current
        var lines: [String] = [
            "Date/time: \(now.formatted(date: .complete, time: .shortened))",
            "",
            "TODAY:"
        ]

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

        guard let tomorrowStart = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else {
            return lines.joined(separator: "\n")
        }

        let weekdayMap: [Int: Locale.Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        let wd = weekdayMap[cal.component(.weekday, from: tomorrowStart)]
        var tomorrowAll = tomorrowItems
        if let wd {
            let ghosted = templates
                .filter { $0.recurringWeekdays.contains(wd) }
                .filter { t in !tomorrowItems.contains { $0.template?.uuid == t.uuid } }
            tomorrowAll += ghosted
        }

        lines.append("")
        lines.append("TOMORROW (\(tomorrowStart.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))):")
        if tomorrowAll.isEmpty {
            lines.append("  (nothing planned)")
        } else {
            for item in tomorrowAll.sorted(by: { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }) {
                var row = "  ○ \(item.title)"
                if let s = item.daySection { row += " [\(s.displayName)]" }
                lines.append(row)
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - CommView

struct CommView: View {

    @State private var viewModel = CommViewModel()
    @FocusState private var inputFocused: Bool

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == false })
    private var allItems: [PlanItem]

    @Query(filter: #Predicate<PlanItem> { $0.isTemplate == true })
    private var templates: [PlanItem]

    private var todayItems: [PlanItem] {
        allItems.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var tomorrowItems: [PlanItem] {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) else { return [] }
        return allItems.filter { cal.isDate($0.date, inSameDayAs: tomorrow) }
    }

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
            if !viewModel.sessionReady {
                viewModel.buildSession(todayItems: todayItems, tomorrowItems: tomorrowItems, templates: templates)
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
            Text("Ask about your day")
                .font(.headline)
            VStack(spacing: 4) {
                Text("\"What's left for this afternoon?\"")
                Text("\"What did I accomplish today?\"")
                Text("\"What's on deck for tomorrow?\"")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
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
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(message.role == .user ? Color.white : Color.primary)
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
