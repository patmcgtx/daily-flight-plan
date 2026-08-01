# Daily Flight Plan

A daily planning and execution app for iOS, inspired by an airplane flight plan checklist. Today is your trip; this is your checklist.

## The original idea

![Initial "back of a napkin" Figma sketch](DailyFlightPlan/docs/daily-flight-plan-figma.png)

## Concept

Combines one-off and recurring tasks, organized into time-of-day sections (Morning, Midday, Afternoon, Evening, Night). Items with specific deadlines appear as timed rows; items assigned to a section appear in a horizontal flow; items with no time at all land in an "Any Time" area at the bottom. A "now" bar tracks your current position in the day.

## Tech stack

- **SwiftUI + Liquid Glass** — primary UI framework with iOS 26 glass effects
- **SwiftData** — local persistence (iCloud sync planned)
- **SwiftUI-Flow** (`HFlow`) — horizontal wrapping flow layouts for item pills
- **`@Observable @MainActor` ViewModels** — no Combine
- **Protocol-based services** injected via `@Environment` + `@Entry`

## Features (current)

- Day view with collapsible time-of-day sections
- Navigate between days with a directional slide animation
- "Go to today" button (appears only when you've navigated away)
- Recurring items with weekday picker
- Deadline-based items with clock-time rows
- "Any time" section for untimed items
- Scroll-to-now on appear
- Theme switcher (Cupertino, 8-Bit, Kerby, Flamingo)

## Project structure

```
DailyFlightPlan/
├── Common/           — App entry point, Environment.swift, service injection
├── Persistence/      — SwiftData models (PlanItem, PlanCategory, DaySection, ItemStatus)
├── Preferences/      — AppStorageKeys enum
├── Theming/          — DFPTheme enum, ThemeViewModifier
└── Views/
    ├── Components/   — DaySectionView, ItemPillView, DeadlineItemRow, NowBarView
    ├── View Models/  — DayViewModel
    └── DayView.swift
```

## Docs

- [`docs/project-spec-prompt.md`](DailyFlightPlan/docs/project-spec-prompt.md) — original feature and UX specs
- [`docs/architecture.md`](DailyFlightPlan/docs/architecture.md) — folder structure, data models, services, UI direction
- [`docs/implementation-plan.md`](DailyFlightPlan/docs/implementation-plan.md) — phased build plan and progress

## Building

Open `DailyFlightPlan/DailyFlightPlan.xcodeproj` in Xcode 26+, select a simulator or device, and run. No additional setup required — SwiftUI-Flow is fetched via Swift Package Manager.
