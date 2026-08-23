//
//  MarkdownImportView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Generable types

@Generable
private struct ParsedTaskList {
    var tasks: [ParsedTask]
}

@Generable(description: "A task extracted from imported text")
private struct ParsedTask {
    @Guide(description: "Clean title without leading dashes, checkboxes, date prefixes, or bullets")
    var title: String

    @Guide(description: "Time of day: firstThing, morning, midday, afternoon, evening, bedtime, or open")
    var section: String

    @Guide(description: "True if this is a recurring habit or regularly repeated task")
    var isRecurring: Bool

    @Guide(description: "Recurring schedule: everyday, weekdays, weekends, or comma-separated abbreviations mon/tue/wed/thu/fri/sat/sun. Empty string if not recurring.")
    var schedule: String
}

// MARK: - ViewModel

@Observable @MainActor
final class MarkdownImportViewModel {

    struct ProposedItem: Identifiable {
        var id = UUID()
        var title: String
        var section: DaySection?
        var isRecurring: Bool
        var weekdays: [Locale.Weekday]
    }

    var rawText: String = ""
    var proposedItems: [ProposedItem] = []
    var isParsing = false
    var isParsed = false
    var errorMessage: String? = nil

    func prepopulateFromClipboard() {
        #if os(iOS)
        rawText = UIPasteboard.general.string ?? ""
        #elseif os(macOS)
        rawText = NSPasteboard.general.string(forType: .string) ?? ""
        #endif
    }

    func parse() async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isParsing = true
        errorMessage = nil
        defer { isParsing = false }

        guard SystemLanguageModel.default.isAvailable else {
            fallbackParse(text)
            isParsed = true
            return
        }

        do {
            let session = LanguageModelSession(instructions: """
                Extract tasks from markdown or plain text. For each line that represents a task:
                Clean the title by stripping "- [ ]", "- [x]", leading bullets (-), and any date \
                prefix in MM/DD/YYYY format (e.g. "08/22/2026").
                Assign a section based on content clues: firstThing (pre-morning health/meds/vitamins), \
                morning (AM habits, breakfast), midday (noon tasks), afternoon (1-5pm), \
                evening (dinner, 5-10pm), bedtime (sleep prep, 10pm+). Use "open" when unsure.
                Mark isRecurring=true for habits done regularly (keywords: Regularly, Daily, Every, \
                exercise, vitamins, meds, routine health checks, household chores done on a schedule).
                For schedule: use "everyday", "weekdays", "weekends", or comma-separated abbreviations.
                Ignore empty lines and lines that are not tasks.
                """)
            let response = try await session.respond(to: text, generating: ParsedTaskList.self)
            proposedItems = response.content.tasks.compactMap { parsed in
                let clean = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return nil }
                let recurring = parsed.isRecurring
                let parsedDays = recurring ? weekdays(from: parsed.schedule) : []
                // Fall back to "everyday" when the model says recurring but gives no recognized schedule,
                // so the item stays recurring and the user can adjust days in the review UI.
                let days = recurring && parsedDays.isEmpty
                    ? [Locale.Weekday.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
                    : parsedDays
                return ProposedItem(
                    title: clean,
                    section: DaySection(importing: parsed.section),
                    isRecurring: recurring,
                    weekdays: days
                )
            }
            isParsed = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        proposedItems = []
        isParsed = false
        errorMessage = nil
    }

    func commit(to context: ModelContext, on date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        for item in proposedItems {
            if item.isRecurring && !item.weekdays.isEmpty {
                let template = PlanItem(
                    title: item.title,
                    date: startOfDay,
                    daySection: item.section,
                    recurringWeekdays: item.weekdays,
                    isTemplate: true
                )
                context.insert(template)
            } else {
                let planItem = PlanItem(
                    title: item.title,
                    date: startOfDay,
                    daySection: item.section
                )
                context.insert(planItem)
            }
        }
        try? context.save()
    }

    private func fallbackParse(_ text: String) {
        proposedItems = text
            .components(separatedBy: .newlines)
            .compactMap { line -> ProposedItem? in
                let stripped = line
                    .replacingOccurrences(of: #"^-\s*\[[ x]?\]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^[-*•]\s+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^\d{2}/\d{2}/\d{4}\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !stripped.isEmpty else { return nil }
                return ProposedItem(title: stripped, section: nil, isRecurring: false, weekdays: [])
            }
    }

    private func weekdays(from schedule: String) -> [Locale.Weekday] {
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
}

// MARK: - View

struct MarkdownImportView: View {

    var selectedDate: Date

    @State private var viewModel = MarkdownImportViewModel()
    @State private var isShowingHelp = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isParsed {
                    reviewView
                } else {
                    pasteView
                }
            }
            .navigationTitle(viewModel.isParsed ? "Review Items" : "Paste Text")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isShowingHelp = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("How it works")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isParsed {
                        Button("Add \(viewModel.proposedItems.count)") {
                            viewModel.commit(to: modelContext, on: selectedDate)
                            dismiss()
                        }
                        .disabled(viewModel.proposedItems.isEmpty)
                    } else {
                        Button("Review") {
                            Task { await viewModel.parse() }
                        }
                        .disabled(
                            viewModel.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || viewModel.isParsing
                        )
                    }
                }
            }
            .sheet(isPresented: $isShowingHelp) { ImportHelpView() }
            .overlay {
                if viewModel.isParsing {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().controlSize(.large)
                            Text("Analyzing…").foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .alert("Import Failed", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .onAppear { viewModel.prepopulateFromClipboard() }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 440)
        #endif
    }

    private var pasteView: some View {
        TextEditor(text: $viewModel.rawText)
            .font(.body.monospaced())
            .padding(8)
    }

    private var reviewView: some View {
        List {
            Section {   
                ForEach($viewModel.proposedItems) { item in
                    let itemID = item.wrappedValue.id
                    ProposedItemRow(
                        item: item,
                        onDelete: { viewModel.proposedItems.removeAll { $0.id == itemID } }
                    )
                }
                .onDelete { offsets in
                    viewModel.proposedItems.remove(atOffsets: offsets)
                }
            } header: {
                Text(
                    "\(viewModel.proposedItems.count) item\(viewModel.proposedItems.count == 1 ? "" : "s") — "
                    + selectedDate.formatted(.dateTime.weekday(.wide).month().day())
                )
            } footer: {
                Button("← Back to text") { viewModel.reset() }
                    .font(.footnote)
            }
        }
    }
}

// MARK: - ProposedItemRow

private struct ProposedItemRow: View {
    @Binding var item: MarkdownImportViewModel.ProposedItem
    let onDelete: () -> Void

    private static let allWeekdays: [(Locale.Weekday, String)] = [
        (.sunday, "Su"), (.monday, "M"), (.tuesday, "T"),
        (.wednesday, "W"), (.thursday, "Th"), (.friday, "F"), (.saturday, "Sa")
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Title", text: $item.title)
                    .font(.body)

                HStack(spacing: 6) {
                    // Section menu
                    Menu {
                        Button { item.section = nil } label: {
                            if item.section == nil {
                                Label("Open", systemImage: "checkmark")
                            } else {
                                Text("Open")
                            }
                        }
                        ForEach(DaySection.allCases) { section in
                            Button { item.section = section } label: {
                                if item.section == section {
                                    Label(section.displayName, systemImage: "checkmark")
                                } else {
                                    Text(section.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(item.section?.displayName ?? "Open")
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    // Routine toggle capsule
                    Button {
                        item.isRecurring.toggle()
                        if item.isRecurring && item.weekdays.isEmpty {
                            item.weekdays = Self.allWeekdays.map(\.0)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "infinity")
                            Text(item.isRecurring ? weekdayLabel : "Routine")
                        }
                        .font(.caption2)
                        .foregroundStyle(item.isRecurring ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            item.isRecurring ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Weekday circles (visible when recurring)
                if item.isRecurring {
                    HStack(spacing: 6) {
                        ForEach(0..<Self.allWeekdays.count, id: \.self) { i in
                            let (weekday, label) = Self.allWeekdays[i]
                            let isOn = item.weekdays.contains(weekday)
                            Button {
                                if isOn {
                                    item.weekdays.removeAll { $0 == weekday }
                                } else {
                                    item.weekdays.append(weekday)
                                }
                            } label: {
                                Text(label)
                                    .font(.caption.bold())
                                    .frame(width: 36, height: 36)
                                    .background(
                                        isOn ? Color.accentColor : Color.secondary.opacity(0.15),
                                        in: Circle()
                                    )
                                    .foregroundStyle(isOn ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.2), value: item.isRecurring)
    }

    private var weekdayLabel: String {
        let days = item.weekdays
        if days.count == 7 { return "Every day" }
        if days.count == 5 && !days.contains(.saturday) && !days.contains(.sunday) { return "Weekdays" }
        if days.count == 2 && days.contains(.saturday) && days.contains(.sunday) { return "Weekends" }
        if days.isEmpty { return "No days" }
        return "\(days.count)×/wk"
    }
}

// MARK: - Help sheet

private struct ImportHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    helpRow(
                        icon: "doc.text",
                        title: "Paste any task list",
                        detail: "Works with Things exports, plain text, or any markdown checklist (- [ ] format). Tap Review and the AI analyzes it."
                    )
                    helpRow(
                        icon: "brain",
                        title: "What the AI does",
                        detail: "Strips checkboxes and date prefixes, picks the best day segment for each task, and flags recurring habits with a suggested schedule."
                    )
                    helpRow(
                        icon: "pencil",
                        title: "Review before saving",
                        detail: "Edit titles, change segments, toggle the Routine days, or tap × to remove an item. Nothing is saved until you tap Add."
                    )
                    helpRow(
                        icon: "exclamationmark.triangle",
                        title: "No Apple Intelligence?",
                        detail: "The app strips formatting and imports every line as an Open, one-off item so you can assign segments manually."
                    )
                }
            }
            .navigationTitle("How it works")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }

    private func helpRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - DaySection import helper

private extension DaySection {
    init?(importing string: String) {
        switch string.lowercased().trimmingCharacters(in: .whitespaces) {
        case "firstthing", "first_thing", "first thing":
            self = .firstThing
        case "morning":
            self = .morning
        case "midday", "noon", "lunch":
            self = .midday
        case "afternoon":
            self = .afternoon
        case "evening":
            self = .evening
        case "bedtime", "night":
            self = .bedtime
        default:
            return nil
        }
    }
}

#Preview {
    MarkdownImportView(selectedDate: .now)
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
