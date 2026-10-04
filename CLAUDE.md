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
- **Known bugs**: `DailyFlightPlan/docs/known-bugs.md` — specific defects (Open) and their
  write-ups once resolved (Fixed); separate from the roadmap/phase narrative in the build plan

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
  When one of those **Open** entries is fixed, move it to **Fixed** in the same file, noting the
  phase it was fixed in — don't write the fix up in `implementation-plan.md`, which should stay
  focused on features, not bug-fix prose. Do this automatically, without being asked. This file
  tracks defects someone noted as worth remembering, not a changelog — bugs caught and fixed
  in-line during normal implementation or code review (e.g. relayed Copilot findings) don't need
  a new entry created from scratch just to fix them.
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
