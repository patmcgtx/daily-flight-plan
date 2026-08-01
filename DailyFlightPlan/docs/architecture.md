# Architecture

Mirrors the MapsPlus app architecture. See https://github.com/patmcgtx/mapplus for the reference.

## Folder structure

```
DailyFlightPlan/
├── Common/           — App entry point, Environment.swift (@Entry service injection), error types
├── Extensions/       — String, Date helpers
├── Persistence/      — @Model classes, ModelContainers factory (persistent + in-memory)
├── Preferences/      — AppStorageKeys enum (all @AppStorage keys go here)
├── Services/
│   ├── Calendar/     — CalendarService protocol + EventKit implementation
│   └── Items/        — ItemService if needed; otherwise use @Query + modelContext directly
├── Test Support/     — Mock service implementations (#if DEBUG only)
├── Theming/          — DFPTheme enum + ThemeViewModifier (adapted from MapsPlus MapPlusTheme)
└── Views/
    ├── Components/   — DaySection, ItemRow, CategoryCapsule, NowBar, ProgressRing, etc.
    ├── View Models/  — DayViewModel, ItemFormViewModel (@Observable @MainActor)
    └── DayView.swift, ItemForm.swift, CategoriesEditView.swift
```

## Key patterns

- **`@Observable @MainActor` ViewModels** — no Combine, no ObservableObject
- **Protocol-based services** injected via `@Environment` + `@Entry` (see MapsPlus `Environment.swift`)
- **`AppStorageKeys` enum** — single source of truth for all `@AppStorage` key strings
- **`#if DEBUG` mock services** — used in SwiftUI previews and tests
- **Theme via single modifier** — `ThemeViewModifier` applied once at the root preserves view identity across theme changes
- **State machine enums** — use enums with associated values for multi-step flows (e.g., save state)

## Data models

```swift
@Model class PlanItem
    title: String
    notes: String
    isFlagged: Bool
    date: Date                  // which calendar day this item belongs to
    deadline: Date?             // specific clock time; nil = "any time"
    daySection: DaySection?     // nil if deadline-based or explicitly "any time"
    isRecurring: Bool
    recurringDays: [Int]        // weekday indices: Sun=1 … Sat=7
    status: ItemStatus          // .pending | .completed | .canceled | .deferred
    categories: [PlanCategory]

@Model class PlanCategory
    name: String
    items: [PlanItem]           // inverse relationship

enum DaySection: String, CaseIterable, Codable
    morning    // up to 10:59am
    midday     // 11:00am – 12:59pm
    afternoon  // 1:00pm – 4:59pm
    evening    // 5:00pm – 7:59pm
    night      // 8:00pm+

enum ItemStatus: String, Codable
    pending | completed | canceled | deferred
```

"Missed" items (past-due and still `.pending`) are computed dynamically — no extra DB field.

## Services

```swift
protocol CalendarService {
    func events(for date: Date) async throws -> [CalendarEvent]
}
// CalendarEvent is a local DTO (id, title, startDate, endDate, calendarItemIdentifier)
// Tapping a CalendarEvent opens Calendar app via UIApplication.open(url)
```

For SwiftData CRUD, views use `@Query` + `modelContext` directly unless complexity warrants a service protocol.

## UI: "Structured Flight Plan"

**Sticky header (two rows, never scrolls):**
- Row 1: `[<]  Friday, Aug 1  [☉]  [>]   [⚙] [🎨]`  — date nav, date-picker placeholder (not yet implemented), settings, theme selector. Small progress ring (donut) in the top-right corner.
- Row 2: `[★ Flagged] [✓ Done] [∞ Recurring]` Liquid Glass toggle pills + horizontally scrollable `CategoryCapsule` row. All filter prefs saved to `@AppStorage`.

**Day sections:** Rounded-rect bordered cards with a subtle tinted background. Collapsible — tap the section header to expand/collapse. Collapsed header shows name + remaining item count.

**"Any time" section:** No border or background. Lives at the bottom of the scroll view. Also receives missed items (past-due, still pending) displayed in orange/red with struck-through original deadline.

**Now bar:** Red horizontal line + "NOW" label at the leading edge, rendered inside whichever section contains the current time.

**Add button:** Centered floating Liquid Glass pill `[+  Add Item  ]` using `safeAreaInset(edge: .bottom)`.

**Item types in the day view:**
| Type | Layout | Icon |
|---|---|---|
| Calendar event | Full-width row | calendar symbol |
| Deadline item | Full-width row | clock symbol |
| Day-section item | `HFlow` within its section | — |
| Any-time item | `HFlow` in any-time area | — |

All non-calendar items have an info button (ⓘ) to view notes, a completion checkbox, and support cancel (swipe left / long-press) and defer-to-tomorrow (swipe right / long-press) gestures. Recurring items show an ∞ icon.
