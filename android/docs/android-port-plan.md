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
- Search and the flagged/recurring filters (first follow-up after v1). The show-completed toggle
  was pulled forward into phase 4; see Status.
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
4. ✅ **Cockpit UI** — built bottom-up: pill, deadline row, section card, Flight Status card,
   briefing row, then the screen and day navigation.
5. ✅ **Item form** — bottom sheet for add/edit, including section and deadline pickers, plus the
   "+" button and each card's "Add item" link, and wiring item taps to open the form.
6. ✅ **Polish** — emulator pass, dark mode, accessibility labels, empty states.

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
- Nothing in the UI used the database until phase 4 wired it up.

Not ported on purpose: search and the flagged/recurring filters (post-v1), and everything tied to
routines, calendar/reminders, or AI summaries.

**Phase 4 (Cockpit UI) done** — 193 JVM tests plus 14 instrumented DAO tests pass; verified by
hand on the API 37 emulator in light and dark mode (expand/collapse, complete, long-press menu,
show-completed, day navigation, editing the destination and seeing it persist).

- Wiring: `DailyFlightPlanApp` owns the lazily-built `PlanRepository`; `MainActivity` creates the
  `CockpitViewModel` from it and hands it to `AppShell`.
- `CockpitViewModel` exposes one `StateFlow<CockpitUiState?>` (null until the first DB read). It
  takes the repository, a `Clock`, and an injectable minute-tick `Flow`, so its tests are fully
  deterministic (`CockpitViewModelTest`). `CockpitUiState` holds the selected date, the clock,
  every item for the day, the `Day`, and the filter/expand state, and derives everything the
  screen needs (`sections`, `openItems`, `progress`, `nextUp`, `priorityCount`).
- New pure model code, all unit-tested: `Progress` + the status filter, `Briefing` (midnight
  countdown that is correct across DST changes, plural labels, past/future blurb),
  `SectionModel`/`DayContext.sectionModel` (what each card draws), `DayContext.relativeDay`,
  `hasOverdue` and `timedRows`.
- UI in `ui/cockpit/`: `PaperStyle` (`paperCard` modifier: flat fill, square border, hard offset
  shadow), `ItemPill`, `DeadlineRow`, `SectionCard` (+ `CardHeader`, `ProgressRing`), `OpenCard`,
  `FlightStatusCard` (progress box, editable flight name and destination, next up, route),
  `BriefingRow` (live clock and countdown ticking each second), `DayLabel`, and `CockpitScreen`
  (stateless `CockpitContent` + a `@Preview` fed by `SampleData`).
- Day navigation uses the ← / → buttons plus a "go to today" button when away from today; the
  expanded sections reset on every date change, and follow the current section as the clock moves
  until the user expands or collapses one by hand.
- Text fields keep a local draft and write to the database on every keystroke (as iOS does); the
  draft is replaced by the stored value only when the field isn't focused.

Deviations and additions:

- **Missed timed items stay visible.** On iOS, a pending timed item whose time has passed today is
  excluded from every section (and nothing renders the "missed" list), so it appears to
  vanish — logged as an unverified report in the iOS `known-bugs.md`. Android keeps these items in
  their section, with the time and "MISSED" in orange, and counts them as still pending
  (`DayContext.timedRows`; the iOS-style `deadlineRows` is kept and tested). Revisit if iOS
  turns out to hide them deliberately.
- **A show-completed toggle (eye icon) was pulled forward from "filters".** iOS hides completed
  items by default and offers a filter menu to reveal them; without any toggle, Android would
  have no way to see completed items. It is in-memory only (resets on relaunch).
- No AI summaries: a collapsed card shows "N remaining" / "All done ✓" / "Nothing scheduled".
- No drag-and-drop between sections. (The date-picker button this note once listed as missing
  was added in phase 6.)
- Menus are Material `DropdownMenu`s restyled as square paper panels.
- To try the screen with sample data without the form, rows can be inserted into the app's
  database over adb (pull `databases/daily-flight-plan.db`, add rows with `sqlite3`, push it
  back), or use the Compose `@Preview` with `SampleData`.

**Phase 5 (item form) done** — 220 JVM tests plus 14 instrumented DAO tests pass; verified by hand
on the emulator by creating, editing, and moving items entirely through the UI (no seeded data),
including the time and date pickers and rotating the device with the form open.

- `model/ItemFormState` holds the form's fields and rules, and is unit-tested
  (`ItemFormStateTest`, ported from the iOS `ItemFormViewModelTests` minus routines/categories):
  a blank title can't be saved; the title is trimmed and notes kept as typed; a timed item has no
  section and its time is cut to the minute; an untimed item has no time; an edit keeps the item's
  id and status. `ItemFormTarget` says which form is open (`New(date, section?)` or `Edit(item)`).
- `CockpitViewModel` owns `formTarget` (so the open form survives rotation) with
  `openNewItemForm`, `openEditForm`, `dismissForm`, and `saveItem`; saving with no form open, or
  with a blank title, does nothing.
- `ui/form/ItemFormSheet`: a Material `ModalBottomSheet` in the paper style with title, notes,
  date, flagged, a "specific time" switch (time picker) or a segment chooser (Open plus the six
  sections). The draft lives in the composable via `rememberSaveable` with a custom saver, so typing
  is instant and a half-filled form survives rotation. A new item's title is focused on open.
- Entry points: the yellow "+" key (Open segment), each expanded card's "+ ADD ITEM" (preselects
  that segment) and the Open card's link, and tapping any pill or timed row (edit).
- The Material color scheme is now fully derived from the Cockpit tokens (`CockpitTheme`), so the
  date picker, time picker, switches, and sheet match instead of showing Material's default purple.
- New items default to Open on the day being viewed; a new timed item's time defaults to the
  current time.

Deviations and limits:

- The date and time pickers are the stock Material ones (themed, but in Roboto rather than
  Plex Mono); the iOS app uses its native graphical pickers.
- There is no delete in the form, as on iOS; "Cancel Item" in the long-press menu is how an item
  goes away. Canceled items stay in the database and show again with the eye toggle.
- An edit saves the item as it was when the form opened, with the form's fields applied. The sheet
  is modal, so nothing else can change the item meanwhile today; if that ever changes (e.g. sync),
  the save should re-read the item first, or it would overwrite the newer status.
- The form's UI is verified by hand, not by automated UI tests; there are no Compose UI tests yet.

**Phase 6 (polish) done** — 257 JVM tests plus 42 instrumented tests (14 DAO, 28 Compose UI) pass;
checked by hand on the API 37 emulator in light, dark, 2x font scale, and landscape.

- **Launcher icon.** Replaced the placeholder with the iOS artwork, rebuilt as adaptive layers: the
  full-colour airplane and flight path are cut out of the iOS art (using the silhouette of the iOS
  "tinted" template), a sunburst background is regenerated (the iOS art has the airplane baked in),
  and the tinted template doubles as the monochrome layer for Android 13+ themed icons. Layers are
  `res/drawable-nodpi/ic_launcher_{background,foreground,monochrome}.png`. They were generated with
  a throwaway script (not kept in the repo); regenerate from `icon-light-1024.png` /
  `icon-tinted-1024.png` if the iOS icon changes.
- **Contrast.** Measured, not assumed: the light-mode status colors failed WCAG (orange 2.3:1,
  green 3.2:1, red 3.9:1 on the card). `done`, `overdue`, and `now` are now theme colors with
  values that clear 4.5:1 in both themes, and `ContrastTest` fails if any text or border pair in
  either palette drops below 4.5:1 (text) or 3:1 (borders/icons).
- **Screen readers.** Section headers read as buttons with an expanded/collapsed state and a spoken
  summary ("Morning, 7:30 – 11 AM, current section, 1 of 3 done, overdue, has flagged items")
  instead of the cryptic ring and "!" badge. Item rows announce Flagged / Completed / Canceled /
  Missed (color and strikethrough carried that alone before) and expose Complete, Flag, Cancel, and
  Defer as custom accessibility actions, so nothing depends on a long-press. The day heading is a
  heading with a full spoken date; the flight progress box is read in words; the segment chips are
  proper radio items that report which is selected. The spoken text is pure and unit-tested
  (`AccessibilityTextTest`).
- **Touch targets.** Complete circles are 40dp, the timed-row check is 48dp, the day arrows and
  "Add item" links are 48dp, and segment chips are 44dp tall. Compose already widens any small
  tappable element to a 48dp hit area, so a touch-bounds check can't fail; the tests measure
  layout size for the controls we size ourselves.
- **Empty states.** A day with nothing on it points at the "+" button. An expanded card whose items
  are all done and hidden says "All done ✓ — Completed items are hidden" instead of "Nothing
  scheduled".
- **Date picker.** A calendar button in the top bar jumps to any day (shares its dialog with the
  item form via `ui/form/PaperPickers.kt`).
- **Large fonts and wide screens.** At 2x font scale the progress box grows with its text, the
  briefing strip stacks instead of clipping its third item, tab labels cap at 1.3x so "Maintenance"
  stays on one line, and card headers wrap by whole pieces instead of mid-word. Content is capped
  at 640dp and centered in landscape and on tablets.
- **Compose UI tests** (`CockpitContentTest`, `ItemFormSheetTest`) assert the semantics above, the
  main actions, the empty states, and the form's behavior. They need Espresso 3.7.0 pinned in the
  catalog: the version Compose's test library pulls in calls `InputManager.getInstance()`, which
  no longer exists on Android 37, and fails every Compose test.

Known gaps after v1: the "NOW ·" separator can dangle at the end of a wrapped header line at large
font sizes; there is no automated screenshot/visual regression testing; behavior with TalkBack
itself was reasoned from the semantics tree and not listened to; and everything listed under "Out"
at the top of this document is still to do.
