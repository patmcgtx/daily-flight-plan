# Android Port Plan

A native Android port of Daily Flight Plan, starting with a deliberately small first version
("v1"). The iOS app remains the source of truth for look, feel, and behavior; see
`DailyFlightPlan/docs/architecture.md` for how the iOS app is built.

## v1 scope

**In:**

- Three-tab bottom bar: Cockpit (working), plus Maintenance and Nav Log as "Coming soon"
  placeholders (tab names match iOS).
- Cockpit tab: day navigation (← / → buttons, date header with Today/Tomorrow/Yesterday label),
  Flight Status card (progress box, editable flight name, editable destination, "Next up at"),
  route line, briefing row (live clock, countdown to midnight, outstanding flagged count), six
  day-section cards plus the Open card, pills for untimed items, rows for timed items.
- Item actions: add, edit, complete, flag, cancel, defer to tomorrow.
- Light mode ("paper") and dark mode ("Paper Night") using the Cockpit tokens.

**Out (explicitly):**

- Sync of any kind — local storage only.
- Routines, templates, recurring items, ghost projections, Nav Log timeline.
- Categories.
- Calendar events and reminders.
- AI summaries.
- Markdown import/export.
- Drag-and-drop between sections.
- Search and filters (first follow-up after v1).
- Settings screen.

## Decisions

| Concern | Choice | iOS equivalent |
|---|---|---|
| Language / UI | Kotlin + Jetpack Compose | Swift + SwiftUI |
| Persistence | Room (SQLite) | SwiftData |
| Preferences | DataStore | `@AppStorage` |
| State | `ViewModel` + `StateFlow` | `@Observable` ViewModels |
| DI | Plain constructor injection (no Hilt yet) | `@Environment` + `@Entry` |
| Fonts | IBM Plex Mono `.ttf` in `res/font` | Bundled fonts |
| Unit tests | JUnit 5 (Jupiter) with `@ParameterizedTest` | Swift Testing |

- **Package / application ID:** `com.patmcgtx.dailyflightplan`
- **minSdk 26** (`java.time` without desugaring); compileSdk/targetSdk to match the installed
  SDK platform.
- Not Kotlin Multiplatform, Flutter, or React Native: the iOS app stays SwiftUI/SwiftData, so
  sharing code would mean rewriting working iOS code.

## Data model (v1)

```
PlanItem
    id: Long (auto)
    title: String
    notes: String
    isFlagged: Boolean
    date: LocalDate          // which calendar day the item belongs to
    deadline: LocalTime?     // specific clock time; null = no specific time
    daySection: DaySection?  // null if deadline-based or explicitly "Open"
    status: ItemStatus       // PENDING | COMPLETED | CANCELED

Day                          // per-day customizations; created lazily on first edit
    date: LocalDate (primary key)
    flightName: String       // "" means the default "DFP YYYYMMDD"
    intention: String        // the day's "destination" note

enum DaySection: FirstThing, Morning, Midday, Afternoon, Evening, Bedtime
enum ItemStatus: Pending, Completed, Canceled
```

(`Day` has no `modifiedAt`, unlike iOS, since it only existed to pick a winner among duplicate
rows.)

Deliberately omitted from the iOS model: `sourceID`, `template`, `instances`,
`recurringWeekdays`, `isTemplate`, `reminderIdentifier`, `categories`. Add them back via Room
migrations when the matching feature is ported. `Day.date` is a primary key, so the iOS
duplicate-`Day` cleanup logic is unnecessary.

Section boundaries come from the iOS `Persistence/DaySection.swift` (not `architecture.md`, whose
section list is stale): first thing 0:00–7:29, morning 7:30–10:59, midday 11:00–12:59, afternoon
1:00–4:59 PM, evening 5:00–9:59 PM, bedtime 10:00 PM–midnight.

## Phases

1. ✅ **Scaffold** — Empty Compose project in `android/`, 3-tab shell with placeholders, theme
   tokens ported from `Theming/CockpitStyle.swift`, bundled font, light/dark.
2. ✅ **Pure logic + tests** — `DaySection`, flight-number formatting, and the section-grouping /
   `nextUpcomingDeadline` / `outstandingFlaggedCount` helpers from `DayViewModel`. The iOS tests
   (`DaySectionTests`, `DayViewModelTests`, `DayTests`) are the specs.
3. ✅ **Room layer** — entities, DAOs, in-memory database for tests.
4. **Cockpit UI** — built bottom-up: pill, deadline row, section card, Flight Status card,
   briefing row, then the screen and day navigation.
5. **Item form** — bottom sheet for add/edit, including section and deadline pickers.
6. **Polish** — emulator pass, dark mode, accessibility labels, empty states.

Follow-ups after v1: search and filters, settings, categories, then routines and the timeline.

## Building and running

The project is hand-written (no Android Studio wizard) and builds from the terminal. Open `android/`
in Android Studio for editing and previews. From `android/`:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME=$HOME/Library/Android/sdk
./gradlew :app:assembleDebug      # build
./gradlew :app:testDebugUnitTest  # JVM unit tests (no device needed)
./gradlew :app:connectedDebugAndroidTest  # DAO tests; needs a running emulator/device
$ANDROID_HOME/emulator/emulator -avd Medium_Phone_API_37.0   # boot the emulator
$ANDROID_HOME/platform-tools/adb install -r app/build/outputs/apk/debug/app-debug.apk
```

`android/local.properties` (gitignored) holds `sdk.dir` and must exist on each machine.

## Status

**Phase 1 (scaffold) done** — builds and runs on the API 37 emulator in light and dark mode.

Notes and deviations:

- Versions: AGP 9.5.1, Kotlin 2.4.21, Gradle 9.9.0, Compose BOM 2026.09.00. AGP 9 ships built-in
  Kotlin, so only the `android.application` and `kotlin.compose` plugins are applied (no
  `kotlin-android`). Versions live in `gradle/libs.versions.toml`.
- Gradle was installed once via Homebrew only to generate the wrapper; after that `./gradlew` is
  all that's needed.
- The Cockpit tab is a placeholder that shows just the date header, to prove the theme and font.
- Icons come from `material-icons-extended`. The launcher icon is a placeholder (black airplane on
  highlighter yellow); replace it per `DailyFlightPlan/docs/app-icon.md` later.
- The iOS `architecture.md` lists stale section times; `DaySection.swift` is the source of truth.

**Phase 2 (pure logic + tests) done** — 96 JUnit tests pass (`./gradlew :app:testDebugUnitTest`).

- New code is in `app/src/main/java/.../model/`: `DaySection`, `ItemStatus`, `PlanItem` (plain
  data class for now; Room annotations arrive in phase 3), `Day`, and `DayContext`.
- `DayContext(selectedDate, now)` is the stateless counterpart of the iOS `DayViewModel`'s logic:
  `isToday`, `currentSection`, `pastSections`, `isDeadlineMissed`, `sectionPills`, `deadlineRows`,
  `missedDeadlineItems`, `anyTimeItems`, `nextUpcomingDeadline`, `outstandingFlaggedCount`. Both
  the date and the clock are injected, so tests never depend on the wall clock (the iOS tests
  mix a fixed clock with the real "today"). The phase 4 view model will wrap it with a live clock.
- Deadlines are `LocalTime` on the item's `date` (iOS stores a full `Date`), so "deferring to
  tomorrow" only changes `date`.
- `Day.withFlightName` caps at 24 Unicode code points, where iOS caps at 24 characters
  (grapheme clusters); they differ only for multi-code-point emoji/accents.
- Tests use JUnit 5 rather than JUnit 4, which has no clean parameterized-test support.
**Phase 3 (Room layer) done** — 120 JVM tests plus 14 instrumented DAO tests pass.

- Room 2.8.5 via KSP 2.3.13 (works with AGP 9's built-in Kotlin). `PlanItem` and `Day` are
  annotated directly as the entities (`plan_items`, `days`) rather than mapped to separate entity
  classes, to avoid boilerplate for a local-only app. Revisit if sync is ever added.
- `data/`: `Converters` (dates as epoch-day integers, times as second-of-day integers, enums by
  name), `PlanItemDao`, `DayDao`, `AppDatabase` (version 1, `getInstance(context)`), and
  `PlanRepository`. Schemas export to `app/schemas/` (committed) for future migration tests.
- `PlanRepository` is the UI layer's one entry point. It depends on the DAO *interfaces*, so its
  rules are tested on the JVM with fake DAOs (`PlanRepositoryTest`): status/flag changes,
  defer-to-tomorrow, and the iOS day-edit rules (a flight name that's blank or equal to the
  default is stored as "", and a `Day` left with nothing customized is deleted). Day edits are
  serialized with a mutex.
- Deviation from iOS: clearing the destination also deletes an otherwise-blank `Day` row; iOS only
  did that for the flight name and left an empty row behind for the destination.
- DAO SQL is tested for real in `app/src/androidTest/.../AppDatabaseTest.kt` (in-memory SQLite on
  the emulator). Instrumented test names are camelCase sentences, since backticked names with
  spaces aren't allowed there below minSdk 30; they use JUnit 4 (`AndroidJUnit4`).
- Nothing in the UI uses the database yet; the app/`AppDatabase.getInstance` wiring happens in
  phase 4.

Not ported on purpose: date navigation (`goToYesterday` etc., trivial — tested with the phase 4
  view model), collapse state, search/status filters (post-v1), and everything tied to routines,
  calendar/reminders, or AI summaries.
