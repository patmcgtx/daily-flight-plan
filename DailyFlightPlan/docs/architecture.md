# Architecture

Mirrors the MapsPlus app architecture. See https://github.com/patmcgtx/mapplus for the reference.

## Folder structure

```
DailyFlightPlan/
├── Common/           — App entry point, Environment.swift (@Entry service injection)
├── Persistence/      — @Model classes, ModelContainers factory (persistent + in-memory)
├── Preferences/      — AppStorageKeys enum (all @AppStorage keys go here)
├── Services/
│   ├── Calendar/     — CalendarService protocol + EventKit implementation + mock (#if DEBUG)
│   ├── Reminders/    — RemindersService protocol + EventKit implementation + mock (#if DEBUG)
│   └── Categories/   — CategorySelectionService + SelectedCategories SwiftData model
├── Theming/          — DFPTheme enum + ThemeViewModifier (adapted from MapsPlus)
└── Views/
    ├── Components/   — DaySectionView, ItemPillView, DeadlineItemRow, CalendarEventRow,
    │                   ReminderItemRow, NowBarView, ProgressRingView, CategoryCapsule
    ├── View Models/  — DayViewModel, ItemFormViewModel, CategoriesEditViewModel
    ├── DayView.swift
    ├── TimelineView.swift
    ├── ItemForm.swift
    └── CategoriesEditView.swift
```

Mock service implementations live alongside their protocols in `#if DEBUG` blocks, not in a separate `Test Support/` folder.

## Key patterns

- **`@Observable @MainActor` ViewModels** — no Combine, no ObservableObject
- **Protocol-based services** injected via `@Environment` + `@Entry` (see `Common/Environment.swift`)
- **`AppStorageKeys` enum** — single source of truth for all `@AppStorage` key strings
- **`#if DEBUG` mock services** — used in SwiftUI previews; `injectMockServices()` view modifier wires them all at once
- **Theme via single modifier** — `ThemeViewModifier` applied once at the root preserves view identity across theme changes

## Data models

```swift
@Model class PlanItem
    uuid: UUID                      // stable drag-and-drop token (separate from persistentModelID)
    title: String
    notes: String
    isFlagged: Bool
    date: Date                      // which calendar day this item belongs to
    deadline: Date?                 // specific clock time; nil = no specific time
    daySection: DaySection?         // nil if deadline-based or explicitly "Open" (any time)
    isRecurring: Bool
    recurringWeekdays: [Locale.Weekday]
    status: ItemStatus              // .pending | .completed | .canceled
    categories: [PlanCategory]
    reminderIdentifier: String?     // EventKit EKReminder identifier, for future two-way sync

@Model class PlanCategory
    name: String
    items: [PlanItem]               // inverse relationship

enum DaySection: String, CaseIterable, Codable
    morning    // up to 10:59am
    midday     // 11:00am – 12:59pm
    afternoon  // 1:00pm – 4:59pm
    evening    // 5:00pm – 7:59pm
    night      // 8:00pm+

enum ItemStatus: String, Codable
    pending | completed | canceled
    // Deferring is a date mutation (item.date = tomorrow), not a status
```

"Missed" items (specific deadline passed, still `.pending`) are computed dynamically — no extra DB field. Section-assigned items stay in their section card regardless of whether that section's time window has passed.

## Services

```swift
protocol CalendarService {
    func events(for date: Date) async throws -> [CalendarEvent]
}
// CalendarEvent DTO: id, title, startDate, endDate, calendarColor
// Tapping opens Calendar app via UIApplication.open(calshow: url)

protocol RemindersService {
    func reminders(for date: Date) async throws -> [ReminderItem]
}
// ReminderItem DTO: id, title, notes, dueDate, listTitle, listColor, isCompleted
// EKEventStoreChanged notification triggers a re-fetch in DayView
```

For SwiftData CRUD, views use `@Query` + `modelContext` directly.

## UI: "Structured Flight Plan"

**Sticky header (two rows, never scrolls):**
- Row 1: `[<] [⏱]  Friday, Aug 1  [☉]  [⚙] [🎨] [>]` — previous day, timeline, date + go-to-today, settings, theme, next day. Small progress ring (donut) sits between settings and theme.
- Row 2: `[★ Flagged] [✓ Done] [📅 Calendar] [🔔 Reminders]` Liquid Glass toggle pills + horizontally scrollable `CategoryCapsule` row. All filter prefs saved to `@AppStorage`.

**Day sections:** All five sections are always visible (past sections remain as a day-at-a-glance reference). Rounded-rect bordered cards, collapsible via tap. When viewing today, inactive sections start collapsed; the current section is always expanded and auto-expands when the clock ticks into it. Collapsed sections display a one-line AI summary (Foundation Models, on-device) inline in the header. Items draggable between sections via long-press; drop target highlights with an accent-colored border.

Each expanded section body renders item sub-rows in order:
1. **Regular pending pills** — `HFlow` row (no icon)
2. **Done row** (✓ icon) — completed pills, `HFlow`; visible only when Done filter is on
3. **Cancelled row** (✗ icon) — cancelled pills, `HFlow`; visible only when Done filter is on
4. **Habits row** (∞ icon) — recurring pending pills + ghosted projected pills, `HFlow`
5. **Deadline rows** — full-width `DeadlineItemRow` entries, sorted by time
6. **Calendar event rows** — full-width `CalendarEventRow` entries
7. **Reminder rows** — full-width `ReminderItemRow` entries

**Special non-section areas (below section cards):**
- **Missed**: pending items whose specific clock-time deadline has passed. Uses `DeadlineItemRow`. No card background.
- **Open**: untimed items (no section, no deadline). Drop target for drag-to-reassign. No card background.

**External item rows** (CalendarEventRow, ReminderItemRow): differentiated by a 3pt colored left accent bar and italic title. No card background.

**Now bar:** Red horizontal line + "NOW" label, rendered inside whichever section contains the current time.

**Add button:** Centered floating Liquid Glass pill `[+  Add Item  ]` using `safeAreaInset(edge: .bottom)`.

**Timeline sheet:** Presented from the `[⏱]` button. Shows all plan items (no calendar/reminders) grouped by date, with filter bar and today indicator. Tap a date or row to dismiss and navigate DayView to that date.

**Item types in the day view:**
| Type | Layout | Visual treatment |
|---|---|---|
| Calendar event | Full-width row | 3pt accent bar left, italic title |
| Reminder item | Full-width row | 3pt accent bar left, italic title |
| Deadline item | Full-width row | clock icon + time |
| Day-section item | `HFlow` pill within its section | — |
| Open (any-time) item | `HFlow` pill in Open area | — |

Pending plan items have a completion checkbox and support cancel (swipe left / long-press) and defer-to-tomorrow (swipe right / long-press). Completed and cancelled items show with strikethrough and dimmed text. Recurring items are grouped on a dedicated Habits row (∞ icon). Future dates show ghosted (35% opacity) projections of recurring habits.
