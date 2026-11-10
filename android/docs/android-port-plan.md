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

enum DaySection: FIRST_THING, MORNING, MIDDAY, AFTERNOON, EVENING, BEDTIME
enum ItemStatus: PENDING, COMPLETED, CANCELED
```

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
2. **Pure logic + tests** — `DaySection`, flight-number formatting, and the section-grouping /
   `nextUpcomingDeadline` / `outstandingFlaggedCount` helpers from `DayViewModel`. The iOS tests
   (`DaySectionTests`, `DayViewModelTests`, `DayTests`) are the specs.
3. **Room layer** — entities, DAOs, in-memory database for tests.
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
./gradlew :app:testDebugUnitTest  # unit tests
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
