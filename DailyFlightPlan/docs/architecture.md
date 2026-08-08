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
    recurringWeekdays: [Locale.Weekday]  // schedule; only meaningful on templates
    isTemplate: Bool                // true for recurring habit templates
    template: PlanItem?             // back-link from a per-day instance to its template
    instances: [PlanItem]           // forward-link from a template to its per-day instances
    isRecurring: Bool               // computed: isTemplate || template != nil
    status: ItemStatus              // .pending | .completed | .canceled
    categories: [PlanCategory]
    reminderIdentifier: String?     // EventKit EKReminder identifier, for future two-way sync

@Model class PlanCategory
    name: String
    items: [PlanItem]               // inverse relationship

enum DaySection: String, CaseIterable, Codable
    firstThing  // before the morning rush
    morning     // up to 10:59am
    midday      // 11:00am – 12:59pm
    afternoon   // 1:00pm – 4:59pm
    evening     // 5:00pm – 7:59pm
    bedtime     // 8:00pm+

enum ItemStatus: String, Codable
    pending | completed | canceled
    // Deferring a one-off item is a date mutation (item.date = tomorrow), not a status.
    // Recurring instances cannot be deferred — cancel today's instance; tomorrow's appears automatically.
```

"Missed" items (specific deadline passed, still `.pending`) are computed dynamically — no extra DB field. Section-assigned items stay in their section card regardless of whether that section's time window has passed.

**Recurring habit model (template + instance):** Each recurring habit is stored as a *template* (`isTemplate = true`). Each day, `DayView` lazily creates a per-day *instance* (`template != nil`) for today only — future dates show read-only ghost projections of the template instead. Instances are independent `PlanItem` records so completing, canceling, or editing one does not affect other days or the template itself. `template` and `instances` use a self-referential `@Relationship` (not a UUID) for CloudKit compatibility. On first launch after upgrade, `migrateOldRecurringItems()` converts any pre-template recurring items to the new model.

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

**Tab bar (system `TabView`, Liquid Glass automatic on iOS 26):**
- **Focus** (`airplane`) — the main day view
- **Timeline** (`calendar.day.timeline.left`) — all plan items grouped by date
- **Search** (`magnifyingglass`, pinned trailing via `Tab(role: .search)`) — stub, not yet implemented

**Navigation bar toolbar (Focus tab only, inside `NavigationStack`):**
- Leading: `⚙` Settings button (stub — navigates to `SettingsView`, not yet implemented)
- Trailing: `ToolbarItemGroup` — filter menu (`line.3.horizontal.decrease.circle`), category button (`tag`), theme menu (`paintbrush`) — system groups these into a single Liquid Glass capsule on iOS 26
- Trailing: `+` Add Item button (separate from the group; Phase 20 (Search) will move this to the thumb zone)

All filter state (`showFlaggedOnly`, `showCompleted`, `showCalendarEvents`, `showReminderItems`) is saved to `@AppStorage`. The filter icon fills/accents when any filter is active.

**Scrolling date header (scrolls with content, not sticky):**
- Centered: weekday + date, with a `scope` go-to-today button when not on today
- Leading/trailing: `[<]` / `[>]` chevron buttons with `.buttonStyle(.glass)` for previous/next day

**Day sections:** All six sections are always visible (past sections remain as a day-at-a-glance reference). Rounded-rect bordered cards, collapsible via tap. When viewing today, inactive sections start collapsed; the current section is always expanded and auto-expands when the clock ticks into it. Collapsed sections display a one-line AI summary (Foundation Models, on-device) inline in the header. Items draggable between sections via long-press; drop target highlights with an accent-colored border.

Each expanded section body renders item sub-rows in order:
1. **Regular pending pills** — `HFlow` row (no icon)
2. **Done row** (✓ icon) — completed pills, `HFlow`; visible only when Done filter is on
3. **Cancelled row** (✗ icon) — cancelled pills, `HFlow`; visible only when Done filter is on
4. **Habits row** (∞ icon) — recurring pending pills + ghosted projected pills, `HFlow`
5. **Deadline rows** — full-width `DeadlineItemRow` entries, sorted by time
6. **Calendar event rows** — full-width `CalendarEventRow` entries
7. **Reminder rows** — full-width `ReminderItemRow` entries

**Special non-section areas (below section cards, scrolls with content):**
- **Progress row**: `ProgressRingView` (small donut) + "X of Y complete" text inline
- **Missed**: pending items whose specific clock-time deadline has passed. Uses `DeadlineItemRow`. No card background.
- **Open**: untimed items (no section, no deadline). Drop target for drag-to-reassign. No card background.

**External item rows** (CalendarEventRow, ReminderItemRow): differentiated by a 3pt colored left accent bar and italic title. No card background.

**Now bar:** Red horizontal line + "NOW" label, rendered inside whichever section contains the current time.

**Timeline tab:** Embedded as a tab (not a sheet). Shows all plan items grouped by date with a filter bar and today indicator. Selecting a date or row navigates the Focus tab to that date and switches back to Focus. Filters (flagged, done, category) are shared state via `@AppStorage`.

**Item types in the day view:**
| Type | Layout | Visual treatment |
|---|---|---|
| Calendar event | Full-width row | 3pt accent bar left, italic title |
| Reminder item | Full-width row | 3pt accent bar left, italic title |
| Deadline item | Full-width row | clock icon + time |
| Day-section item | `HFlow` pill within its section | — |
| Open (any-time) item | `HFlow` pill in Open area | — |

Pending plan items have a completion checkbox and support cancel and (for one-off items only) defer-to-tomorrow via long-press context menu. Completed and cancelled items show with strikethrough and dimmed text. Recurring instances are grouped on a dedicated Habits row (∞ icon). Future dates show ghosted (35% opacity, non-interactive) projections of recurring habit templates instead of real instances.
