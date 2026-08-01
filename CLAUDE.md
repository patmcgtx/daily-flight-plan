# Daily Flight Plan — Claude Context

## What this app is
A daily planner iOS app inspired by a flight plan checklist. Today is a "trip"; the checklist is your flight plan. Combines one-off and recurring tasks, organized by time-of-day sections.

## Key docs
- **Specs**: `DailyFlightPlan/docs/daily-flight-planner.md` — original feature and UX specs
- **Architecture**: `DailyFlightPlan/docs/architecture.md` — folder structure, data models, services, UI direction
- **Build plan**: `DailyFlightPlan/docs/implementation-plan.md` — phased implementation order

## Reference architecture
Mirror the MapsPlus app: https://github.com/patmcgtx/mapplus

Use `gh api repos/patmcgtx/mapplus/git/trees/main?recursive=1` to browse, and
`gh api repos/patmcgtx/mapplus/contents/PATH | python3 -c "import sys,json,base64; print(base64.b64decode(json.load(sys.stdin)['content']).decode())"` to read files.

Key files to copy/adapt: `Theming/`, `Views/Components/CategoryCapsule.swift`, `Views/Components/CategoriesSelectFlow.swift`, `Common/Environment.swift`, `Persistence/ModelContainers.swift`, `Preferences/AppStorageKeys.swift`, `Test Support/`

## Core tech
- SwiftUI + Liquid Glass (`.glassEffect()`, `GlassEffectContainer`)
- SwiftData for persistence (iCloud sync deferred)
- SwiftUI-Flow (`HFlow`) for category/item flow layouts
- `@Observable @MainActor` ViewModels, protocol-based services via `@Environment` + `@Entry`
