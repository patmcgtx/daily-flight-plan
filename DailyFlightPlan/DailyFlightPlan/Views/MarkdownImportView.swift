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
                let days = recurring ? weekdays(from: parsed.schedule) : []
                return ProposedItem(
                    title: clean,
                    section: DaySection(importing: parsed.section),
                    isRecurring: recurring && !days.isEmpty,
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
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isParsed {
                        Button("Add \(viewModel.proposedItems.count)") {
                            viewModel.commit(to: modelContext, on: selectedDate)
                            dismiss()
                        }
                        .disabled(viewModel.proposedItems.isEmpty)
                    } else {
                        Button("Parse") {
                            Task { await viewModel.parse() }
                        }
                        .disabled(
                            viewModel.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || viewModel.isParsing
                        )
                    }
                }
            }
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
                ForEach(viewModel.proposedItems) { item in
                    ProposedItemRow(item: item)
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
    let item: MarkdownImportViewModel.ProposedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.body)
            HStack(spacing: 6) {
                if let section = item.section {
                    Text(section.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                if item.isRecurring {
                    Label(weekdayLabel, systemImage: "infinity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var weekdayLabel: String {
        let days = item.weekdays
        if days.count == 7 { return "Every day" }
        if days.count == 5 && !days.contains(.saturday) && !days.contains(.sunday) { return "Weekdays" }
        if days.count == 2 && days.contains(.saturday) && days.contains(.sunday) { return "Weekends" }
        return "\(days.count)×/wk"
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
