# Daily Flight Plan — Claude Context

## What this app is
A daily planner iOS app inspired by a flight plan checklist. Today is a "trip"; the checklist is
your flight plan. Combines one-off and recurring tasks, organized by time-of-day sections.

## Key docs
- **Specs**: `DailyFlightPlan/docs/project-spec-prompt.md` — original feature and UX specs
- **Architecture**: `DailyFlightPlan/docs/architecture.md` — folder structure, data models,
  services, UI direction
- **Build plan**: `DailyFlightPlan/docs/implementation-plan.md` — phased implementation order
- **App icon**: `DailyFlightPlan/docs/app-icon.md` — design description and asset catalog notes
- **Known bugs**: `DailyFlightPlan/docs/known-bugs.md` — specific, reproducible defects (Open);
  entries are removed outright once fixed rather than moved to a "Fixed" section; separate from
  the roadmap/phase narrative in the build plan
- **Android port plan**: `android/docs/android-port-plan.md` — scope, stack, data model, and
  phases for the native Android app (Kotlin + Jetpack Compose + Room) in `android/`

## Android port
- Lives in `android/` (package `com.patmcgtx.dailyflightplan`); the iOS app stays the source of
  truth for look, feel, and behavior. Everything above describes the iOS app unless stated.
- After completing an Android phase, mark it ✅ in `android/docs/android-port-plan.md` and note
  deviations — not in the iOS `implementation-plan.md`.
- Android tests use JUnit 5 with plain-English backtick names (e.g.
  ``fun `Containing resolves the correct section at each boundary minute`()``; avoid `.` `:` `[`
  `]` `/` in names — the JVM rejects them), and prefer `@ParameterizedTest` + `@MethodSource` over
  near-identical tests — mirroring the Swift Testing conventions below. See
  `android/app/src/test/.../model/DaySectionTest.kt` for the reference pattern. Inject the clock
  (`DayContext(selectedDate, now)`) rather than reading the real one. Test business rules on the
  JVM against fake DAOs (`PlanRepository` takes the DAO interfaces); only the SQL itself goes in
  instrumented tests (`src/androidTest`, JUnit 4, camelCase-sentence names since backticked names
  with spaces aren't allowed there below minSdk 30). Compose UI tests there assert what a screen
  reader sees (content descriptions, state descriptions, custom actions) and touch-target sizes —
  keep Espresso pinned in the version catalog or every Compose test fails on Android 37.
- Build/test from `android/` with `./gradlew :app:testDebugUnitTest` (JVM) and
  `./gradlew :app:connectedDebugAndroidTest` (needs a running emulator), using Android Studio's
  bundled JDK as `JAVA_HOME` (see the plan doc).

## Reference architecture
Mirror the MapsPlus app: https://github.com/patmcgtx/mapplus

Use `gh api repos/patmcgtx/mapplus/git/trees/main?recursive=1` to browse, and
`gh api repos/patmcgtx/mapplus/contents/PATH | python3 -c "import sys,json,base64; print(base64.b64decode(json.load(sys.stdin)['content']).decode())"` to read files.

Key files to copy/adapt: `Theming/`, `Views/Components/CategoryCapsule.swift`,
`Views/Components/CategoriesSelectFlow.swift`, `Common/Environment.swift`,
`Persistence/ModelContainers.swift`, `Preferences/AppStorageKeys.swift`, `Test Support/`

## Working conventions
- After completing a phase (or a meaningful chunk of one), mark it ✅ in
  `DailyFlightPlan/docs/implementation-plan.md` and note any deviations or additions made during
  implementation. Do this automatically, without being asked.
- When a specific, reproducible defect is found (not a roadmap/polish idea), add it to the
  **Open** section of `DailyFlightPlan/docs/known-bugs.md` rather than `implementation-plan.md`.
  When one of those **Open** entries is fixed, remove the entry outright — don't move it to a
  "Fixed" section, and don't write the fix up in `implementation-plan.md` either, which should
  stay focused on features, not bug-fix prose. Fixed bugs don't need to stay documented; commit
  history is the record of what was fixed and when. Do this automatically, without being asked.
  This file tracks defects someone noted as worth remembering, not a changelog — bugs caught and
  fixed in-line during normal implementation or code review (e.g. relayed Copilot findings) don't
  need a new entry created from scratch just to remove it again.
- Hard-wrap prose in markdown docs (`docs/*.md`, this file) to roughly 100 characters per line —
  long unwrapped lines trip Marked 2's long-line warning banner. Indent list-item continuation
  lines by 2 spaces (to align under `- `) so they stay part of the same bullet instead of
  breaking out of the list.

## Core tech
- SwiftUI + Liquid Glass (`.glassEffect()`, `GlassEffectContainer`)
- SwiftData for persistence (iCloud sync deferred)
- SwiftUI-Flow (`HFlow`) for category/item flow layouts
- `@Observable @MainActor` ViewModels, protocol-based services via `@Environment` + `@Entry`

## Testing conventions
- Swift Testing (`import Testing`), not XCTest — test suites are plain `struct`s, assertions
  use `#expect`
- Every `@Test` gets a plain-English description string, e.g.
  `@Test("Containing(_:) resolves the correct section at each boundary minute")` — no bare
  `func testFoo()` names
- Prefer parameterized cases over repeated near-identical test functions:
  `@Test("...", arguments: [...])` with a tuple/array of inputs and expected outputs
- See `DailyFlightPlanTests/DaySectionTests.swift` for the reference pattern
