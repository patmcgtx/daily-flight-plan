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
    ├── DayView.swift          — TabView host: manages shared state, fetches calendar/reminders, owns all sheets
    ├── FlightPlanView.swift   — Flight Plan tab (struct FlightPlanView): primary day view, swipe pager
    ├── RoutineView.swift      — Routine tab: manage recurring habit templates; grouped by weekday pattern and day segment
    ├── CardDeckView.swift     — Cards tab (commented out): collapsible stacked section cards with AI summaries
    ├── TimelineView.swift     — Nav Log tab: chronological multi-day interactive list
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
- **Day** (`airplane`) — primary day view (Flight Plan); swipe pager between days; collapsible section cards with progress ring, HFlow pills, Calendar events, and Reminders
- **Log** (`checklist`) — chronological multi-day list of all plan items; fully interactive
- **Routine** (`infinity`) — recurring habit template management: collapsible cards grouped by weekday pattern (Every Day / Weekdays / Weekends / custom); tap header to expand/collapse (all start expanded; collapsed shows name + item count); within each card, items subdivided by day segment with `HFlow` pills for untimed items and full-width rows for timed deadline items; tap to edit, long-press context menu (Edit/Delete), drag between cards to reassign weekday pattern; add/delete custom weekday sections
- **Comm** (`apple.intelligence`) — placeholder for future AI chat / quick entry
- macOS keyboard shortcuts: `Cmd+1` Day, `Cmd+2` Log, `Cmd+3` Routine, `Cmd+4` Comm

**Navigation bar toolbar (Flight Plan tab, inside `NavigationStack`):**
- Leading: `⚙` Settings button
- Trailing: `ToolbarItemGroup` — filter menu (`line.3.horizontal.decrease.circle`) with Flagged/Done/Routines/Calendar/Reminders toggles; category button (`tag`); theme menu — system groups into a single Liquid Glass capsule on iOS 26
- Trailing: `+` Add Item button (separate from the group)

All filter state (`showFlaggedOnly`, `showCompleted`, `showCalendarEvents`, `showReminderItems`, `showRecurring`) is saved to `@AppStorage` and shared across all tabs. The filter icon fills/accents when any filter is active.

**Flight Plan tab (`FlightPlanView.swift`):**
- **Day pager**: `TabView(.page)` with 3 pages (yesterday / today / tomorrow) on iOS; infinite-reset pattern silently snaps back to center page after each swipe. `DragGesture` fallback on macOS.
- **Date header**: "Today" label in accent color when on today; weekday label otherwise. `scope` go-to-today button at the leading edge when not on today.
- **Section cards**: one `RoundedRectangle(cornerRadius: 18)` card per day section. Collapsed (header + count) / expanded (full content). Tap anywhere in the header to toggle. Current section highlighted with accent border.
- **Collapsed header**: section name, time range, `completed/total` badge, and AI summary text (or loading dots).
- **Expanded section body**:
  1. `HFlow` pills for non-deadline items — each pill is `.draggable`
  2. `DeadlineItemRow` entries for timed items
  3. `CalendarEventRow` entries (from DayView's fetch; selected-date only)
  4. `ReminderItemRow` entries (from DayView's fetch; selected-date only)
  5. `+ Add item` link at top
- **Progress ring**: per-section small donut showing raw `completed/total` plan-item counts (filter-independent); green when all done.
- **Open card**: `HFlow` pills for untimed items + any-time `ReminderItemRow`s. Also a drop target.
- **Drag-and-drop**: drop onto any section card or Open card reassigns `daySection` and clears deadline. Drop target highlights with accent border.
- **Filter-driven expand/collapse**: when a filter is active, sections with matching items/events/reminders expand; empty sections collapse. User can manually override afterward.
- **`+ Add item`** inside each section card header links to `ItemForm(date:section:)`.

**Nav Log tab:** Embedded as a tab. Shows all plan items grouped by date with a filter bar and today indicator. Items are fully interactive in-place: checkbox completes, tap opens edit form, long-press shows Edit/Cancel context menu. Filters (flagged, done, category) are shared state via `@AppStorage`.

**Cards tab (commented out):** One card per day section in a vertically scrollable stack. Cards start collapsed (shows AI summary or count fallback + time range + completion count) and expand on tap to show the full item list. The current section is expanded by default on today. Date navigation header matches Flight Plan. AI summaries generated on `.onAppear`. `+ Add item` inside expanded card content.

**Cockpit tab (commented out):** Original main day view with scrolling date header, `NowBarView`, grouped item sub-rows (pending / done / cancelled / habits), AI section summaries, and the full DaySectionView component. Kept for reference; may be retired in Phase 24.

**Item types in the day view:**
| Type | Layout | Visual treatment |
|---|---|---|
| Calendar event | Full-width row | 3pt accent bar left, italic title |
| Reminder item | Full-width row | 3pt accent bar left, italic title |
| Deadline item | Full-width row | clock icon + time |
| Day-section item | `HFlow` pill within its section | — |
| Open (any-time) item | `HFlow` pill in Open area | — |

Pending plan items have a completion checkbox and support cancel and (for one-off items only) defer-to-tomorrow via long-press context menu. Completed and cancelled items show with strikethrough and dimmed text. Recurring instances are grouped on a dedicated Habits row (∞ icon). Future dates show ghosted (35% opacity, non-interactive) projections of recurring habit templates instead of real instances.
