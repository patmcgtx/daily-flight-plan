# Architecture (Android)

How the native Android app is built. It is a deliberately small v1 port of the iOS app (see
`DailyFlightPlan/docs/architecture.md`); the iOS app stays the source of truth for look, feel, and
behavior. Scope, decisions, and phase-by-phase notes live in `android-port-plan.md`.

The shape mirrors the iOS app's layering: plain pure logic at the bottom, a persistence layer
behind a small interface, one view model per tab, and stateless views on top.

## Stack

| Concern | Choice | iOS equivalent |
|---|---|---|
| Language / UI | Kotlin 2.4 + Jetpack Compose (BOM 2026.09), Material 3 as a base only | Swift + SwiftUI |
| Persistence | Room 2.8 (SQLite) via KSP | SwiftData |
| State | `ViewModel` + `StateFlow` | `@Observable @MainActor` ViewModels |
| DI | Hand-rolled, constructor injection from `Application` (no Hilt) | `@Environment` + `@Entry` |
| Fonts | IBM Plex Mono `.ttf` in `res/font` | Bundled fonts + `UIAppFonts` |
| Tests | JUnit 5 (JVM) + JUnit 4 / Compose UI tests (device) | Swift Testing |

- minSdk 26 (`java.time` without desugaring), compileSdk/targetSdk 37; Android Gradle Plugin 9.5
  with built-in Kotlin, Gradle 9.9 wrapper. Versions live in `gradle/libs.versions.toml`.
- Package / application ID: `com.patmcgtx.dailyflightplan`. Single module (`app`).
- Local storage only: no sync, no network, no preferences store yet. (DataStore is the planned
  `@AppStorage` equivalent for when the first persisted preference arrives — today the
  show-completed toggle and expanded sections are in-memory view-model state.)

## Folder structure

```
android/
├── gradle/libs.versions.toml     — version catalog (every dependency and plugin version)
├── app/
│   ├── schemas/                  — exported Room schemas (committed, for future migration tests)
│   └── src/
│       ├── main/java/com/patmcgtx/dailyflightplan/
│       │   ├── DailyFlightPlanApp.kt   — Application; owns the lazily built PlanRepository
│       │   ├── MainActivity.kt         — builds the CockpitViewModel, sets the Compose content
│       │   ├── model/                  — pure Kotlin domain: entities + clock-injected logic
│       │   ├── data/                   — Room: database, DAOs, converters, PlanRepository
│       │   └── ui/
│       │       ├── AppShell.kt         — three-tab Scaffold + NavigationBar
│       │       ├── ComingSoonScreen.kt — placeholder for Maintenance and Nav Log
│       │       ├── theme/              — CockpitStyle (tokens), CockpitTheme (Material mapping)
│       │       ├── cockpit/            — the Cockpit tab: view model, screen, cards, rows, pills
│       │       └── form/               — add/edit bottom sheet and the date/time pickers
│       ├── main/res/                   — fonts, adaptive launcher icon, themes, strings
│       ├── test/                       — JVM unit tests (JUnit 5), fake DAOs
│       └── androidTest/                — device tests: DAO (SQL) and Compose UI
```

### `model/` — pure domain logic

No Android framework types except the Room annotations on the two entities. Everything here is
deterministic: callers pass the date being viewed and "now", so tests never touch a real clock.

| File | What it holds |
|---|---|
| `PlanItem.kt` | `@Entity plan_items`: id, title, notes, isFlagged, date, deadline, daySection, status |
| `Day.kt` | `@Entity days`: per-date flight name + intention; default `DFP YYYYMMDD` number |
| `DaySection.kt` | Six-section enum with minute ranges, labels, and `containing(LocalTime)` |
| `ItemStatus.kt` | `Pending`, `Completed`, `Canceled` |
| `DayContext.kt` | `DayContext(selectedDate, now)` — the stateless counterpart of the iOS `DayViewModel` logic (see below) |
| `SectionModel.kt` | Everything one section card needs, via `DayContext.sectionModel(...)`; plus the screen-reader strings |
| `Progress.kt` | `Progress(completed, total)`; `excludingCanceled`, `matchingStatusFilter` |
| `Briefing.kt` | Briefing-row text: time left until midnight (DST-correct), priority label, day blurb |
| `ItemFormState.kt` | The add/edit form's draft (`isValid`, `toPlanItem`, `from`) and `ItemFormTarget` |

### `data/` — persistence

- `AppDatabase` — Room database, version 1, entities `PlanItem` and `Day`, singleton via
  `getInstance(context)`; schemas exported to `app/schemas/`.
- `PlanItemDao` / `DayDao` — interfaces. `observeForDate` returns a `Flow`, ordered timed items
  first (by time) then by id. `DayDao` is get / observe / upsert / delete.
- `Converters` — `LocalDate` as epoch day, `LocalTime` as second-of-day (so both sort correctly in
  SQL); enums are stored by name.
- `PlanRepository` — the single entry point the UI layer uses. Depends on the two DAO *interfaces*
  (not the database), so its rules are unit-tested on the JVM with fake DAOs.

### `ui/` — Compose

- `theme/CockpitStyle.kt` — color tokens (`CockpitColors`, light "paper" and dark "Paper Night"),
  the type scale, and `mono()`, ported from `CockpitStyle.swift`. Values must stay in sync with
  iOS, except that the status colors (`done`, `overdue`, `now`) are Android-specific darker/lighter
  variants chosen to meet WCAG 4.5:1 (`ContrastTest` enforces it).
- `theme/CockpitTheme.kt` — wraps `MaterialTheme` with a color scheme derived from the Cockpit
  tokens, so stock Material pieces (sheets, pickers, nav bar) pick up the paper look.
- `cockpit/` — view model, screen, and the card components (see "Cockpit tab").
- `form/` — `ItemFormSheet` (modal bottom sheet) and `PaperPickers` (themed date/time dialogs).

## Key patterns

- **Pure logic, injected clock** — `DayContext(selectedDate, now)` holds no state and does no I/O.
  The view model supplies a live `now`; tests supply a fixed one. This replaces iOS's reliance on
  `DayViewModel` for the same helpers (`isDeadlineMissed`, `nextUpcomingDeadline`,
  `outstandingFlaggedCount`, …).
- **Unidirectional data flow** — Room `Flow`s → repository → view model combines them into one
  immutable `CockpitUiState` → stateless composables render it → user input calls view model
  functions → repository writes → Room re-emits. Nothing in the UI mutates state directly.
- **Stateless content, thin stateful screen** — `CockpitScreen` is the only composable that sees
  the `ViewModel`; it collects state, bundles view-model functions into a `CockpitActions` data
  class, and hands both to `CockpitContent`, which is previewable and UI-testable with no view
  model or database. `ItemActions` nests inside it for the per-item callbacks.
- **Plain dependency injection** — `DailyFlightPlanApp.repository` is built lazily;
  `MainActivity` builds the view model with `viewModelFactory { initializer { … } }`. The view
  model also takes a `Clock` and a minute-tick `Flow` as defaulted constructor parameters so tests
  can substitute both.
- **Entities are the domain classes** — `PlanItem` and `Day` carry Room annotations directly
  rather than having separate entity and domain types. Acceptable while the model is this small;
  split them if routines or sync make the table shape diverge from the domain shape.
- **Immutable edits** — items are `data class`es; every change is `item.copy(...)` passed to
  `update`. There is no in-place mutation, unlike SwiftData's reference-type `@Model`.
- **Accessibility as a first-class output** — screen-reader text is built in the model layer
  (`SectionModel.accessibilitySummary`, `PlanItem.accessibilityState`, `Progress.spokenStatus`)
  so it is unit-testable; composables apply it with `clearAndSetSemantics`, `stateDescription`,
  and `customActions` (long-press menu actions are also exposed as accessibility actions).

## Data models

```kotlin
@Entity(tableName = "plan_items", indices = [Index("date")])
data class PlanItem(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val notes: String = "",
    val isFlagged: Boolean = false,
    val date: LocalDate,              // which calendar day this item belongs to
    val deadline: LocalTime? = null,  // specific clock time; null = no specific time
    val daySection: DaySection? = null, // null if deadline-based or explicitly "Open" (any time)
    val status: ItemStatus = ItemStatus.Pending,
)

@Entity(tableName = "days")           // created lazily on first edit; most days have no row
data class Day(
    @PrimaryKey val date: LocalDate,  // lookup key; items match by date, not by relationship
    val flightName: String = "",      // "" means use the default "DFP YYYYMMDD" flight number
    val intention: String = "",       // the day's "destination" note
)

enum class DaySection { FirstThing, Morning, Midday, Afternoon, Evening, Bedtime }
// before 7:30 AM / 7:30–10:59 / 11:00–12:59 / 1:00–4:59 PM / 5:00–9:59 PM / 10 PM–midnight
// (DaySection.kt is the source of truth for the ranges, same as DaySection.swift on iOS)

enum class ItemStatus { Pending, Completed, Canceled }
// Deferring is a date change (item.date = tomorrow), not a status. Timed items can't be deferred.
```

Differences from the iOS model, all consequences of the v1 scope:

- No `recurringWeekdays`, `isTemplate`, `template`/`instances`, `uuid`, `categories`, or
  `reminderIdentifier`. No routines means none of iOS's template/instance identity or
  deduplication rules apply.
- `Day.date` is the primary key, so there is no duplicate-`Day` cleanup pass or `modifiedAt`.
- Dates are `LocalDate` and times are `LocalTime` (iOS stores a `Date` for both and normalizes
  to start-of-day), so there is no time-zone drift in stored values.
- `Day` blank rows are never kept: `PlanRepository` deletes a `Day` once both fields are blank,
  and treats a flight name equal to the default number as "unset".

"Missed" items (a specific deadline has passed and the item is still `Pending`) are computed, not
stored — `DayContext.isDeadlineMissed`. Section-assigned items stay in their section card
regardless of the section's time window. **Deliberate divergence:** missed timed items stay
visible in their section (drawn as MISSED) on Android; the iOS Cockpit appears to hide them (see
`known-bugs.md`, Unverified Reports).

## Repository API

```kotlin
class PlanRepository(items: PlanItemDao, days: DayDao) {
    fun observeItems(date): Flow<List<PlanItem>>   // every status, incl. canceled; caller filters
    suspend fun addItem(item): Long
    suspend fun updateItem(item)
    suspend fun deleteItem(item)
    suspend fun setStatus(item, status)
    suspend fun toggleFlag(item)
    suspend fun deferToTomorrow(item)              // date + 1 day, time of day kept

    fun observeDay(date): Flow<Day?>               // null = not customized
    suspend fun setFlightName(date, text)          // blank/default → ""; max 24 code points
    suspend fun setIntention(date, text)
}
```

Day edits are read-modify-write, so they run under a `Mutex` to keep two quick edits from
clobbering each other. This is the whole "services" layer for v1: there are no Calendar or
Reminders services (both are out of scope), so the iOS `CalendarService`/`RemindersService`
protocols have no Android counterpart yet.

## UI: the Cockpit tab

**Tab bar** — `AppShell` is a `Scaffold` with a Material `NavigationBar`: **Cockpit** (flight
icon, built), **Maintenance** (wrench) and **Nav Log** (checklist) as `ComingSoonScreen`
placeholders. Tab names and order match iOS. The selected tab is `rememberSaveable`. Tab label
font scale is capped at 1.3× so "Maintenance" never wraps mid-word.

**Screen composition** — `CockpitContent` is a top action row above one vertical scroll of cards,
capped at 640 dp wide and centered on tablets and in landscape, with a floating "+" button:

1. **Top actions** — date picker, go-to-today, show-completed toggle (all 48 dp targets)
2. **`DayLabel`** — `←` / `→` buttons around the date heading, with the Today / Tomorrow /
   Yesterday label (Today on a highlighter badge); exposed as a heading
3. **`FlightStatusCard`** — growing square completed/total box; editable flight name; editable
   "Destination" (day intention); "Next up at …"; route line of the six sections
4. **`BriefingRow`** — live clock, countdown to midnight, outstanding-flag count between paper
   rules; on non-today days a blurb replaces clock and countdown. Stacks vertically above 1.3×
   font scale instead of clipping
5. **`EmptyDayHint`** — shown only when the day has no items
6. **Six `SectionCard`s** — collapsible, flat square border with a hard offset shadow; the
   current section's name gets the highlighter; progress ring; overdue/flagged cues; body is
   untimed items as flow-wrapped `ItemPill`s then timed items as `DeadlineRow`s; "All done ✓"
   when completed items are hidden and nothing else is left; an "Add item" link
7. **`OpenCard`** — untimed, unsectioned items, shown only when non-empty

**Item interactions** — tap opens the edit sheet; the circle completes; long-press opens a square
paper context menu (Complete, Flag, Cancel, Defer). The same actions are exposed as screen-reader
custom actions. Completed and canceled items are struck through and dimmed.

**Add/edit** — `ItemFormSheet` is a `ModalBottomSheet`: title, notes, flagged switch, then either a
segment chip row (First Thing … Bedtime, or Open) or a specific time, plus a date row. The draft
is held in `rememberSaveable` with a custom saver; the open/closed target lives in the view model
so the form survives rotation. A blank title can't be saved.

**Theming** — `CockpitTheme` supplies `CockpitColors` via `LocalCockpitColors` (read as
`CockpitStyle.colors`) and a Material `ColorScheme` mapped from the same tokens, following the
system light/dark setting. Material is used for behavior (sheets, pickers, nav bar, ripple), then
restyled to flat fills, square borders, hard shadows (`Modifier.paperCard`), IBM Plex Mono
(`CockpitStyle.mono`), and highlighter yellow; text on yellow is always `inkOnHighlighter`.

## State management: `CockpitViewModel`

```
selectedDate ─► flatMapLatest ─► combine(observeItems(date), observeDay(date)) ─► DayData ┐
nowTicks (minute) ───────────────────────────────────────────────────────────────────────┤
showCompleted ───────────────────────────────────────────────────────────────────────────┼─► uiState
expandedOverride (date, sections) ───────────────────────────────────────────────────────┘
```

- `uiState: StateFlow<CockpitUiState?>` is `null` until the first database read lands, then an
  immutable snapshot. `stateIn(WhileSubscribed(5_000))` keeps it alive through rotation.
- `CockpitUiState` is plain data; its derived values (`visible`, `sections`, `openItems`,
  `progress`, `nextUp`, `priorityCount`) are `lazy`, computed from a `DayContext`.
- **Progress counts ignore the status filter** (raw = every non-canceled item); the filter only
  decides what is drawn. This matches iOS.
- **Expanded sections** — today opens with its current section expanded, every other day fully
  collapsed. Manual toggles are stored as `(date, sections)`, so an override from one day can never
  apply to another; navigating clears it.
- **Clock** — `minuteTicks(clock)` emits immediately, then on every minute boundary, driving
  "missed" status and the current section. The second-by-second clock in `BriefingRow` is local
  Compose state (`produceState`), as on iOS (`SwiftUI.TimelineView`), so the rest of the screen
  recomposes only once a minute.
- **Form target** is a separate `StateFlow<ItemFormTarget?>` (`New(date, section?)` /
  `Edit(item)`); `saveItem` is a no-op if no form is open.
- All repository calls go through a private `launch { }` on `viewModelScope`.

## Build, test, and verify

Commands are in `android-port-plan.md` ("Building and running"). Conventions are in the root
`CLAUDE.md` ("Android port"); the short version:

- **JVM tests** (`src/test`, JUnit 5, backtick names, `@ParameterizedTest` + `@MethodSource`) cover
  all business rules: the model, `PlanRepository` against fake DAOs, `CockpitViewModel` with an
  injected clock and tick flow, accessibility strings, and WCAG contrast of every text/background
  pair (`ContrastTest`). Reference pattern: `model/DaySectionTest.kt`.
- **Device tests** (`src/androidTest`, JUnit 4, camelCase-sentence names) cover only what needs a
  device: the SQL in `AppDatabaseTest` (in-memory Room), and Compose UI tests for
  `CockpitContent` and `ItemFormSheet` that assert what a screen reader sees (content
  descriptions, state descriptions, custom actions) and touch-target sizes. Espresso is pinned in
  the version catalog, or every Compose test fails on Android 37.
- Visual changes are checked by hand on the emulator (light, dark, 2× font, landscape); there are
  no screenshot tests.

## What is not here yet

Everything under "Out" in `android-port-plan.md`: sync, routines and templates, the Nav Log
timeline, categories, Calendar and Reminders, AI summaries, markdown import/export, drag-and-drop
between sections, search and filters, and a settings screen. When those arrive, the likely
architectural changes are: a `data/` service layer for Calendar/Reminders (protocol + real +
fake, mirroring iOS `Services/`), DataStore-backed preferences (the `AppStorageKeys` equivalent),
a view model per additional tab, and splitting entity from domain types if routines or sync make
the two diverge.
