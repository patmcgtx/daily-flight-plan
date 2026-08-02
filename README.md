# Daily Flight Plan

A daily planning and execution app for iOS, inspired by an airplane flight plan checklist. Today is your trip; this is your checklist.

I took an app idea in my mind, sketched it out in Figma, broke that into a detailed requirements spec, and fed that to a Claude agent to make an architecture and a plan.

- [`docs/project-spec-prompt.md`](DailyFlightPlan/docs/project-spec-prompt.md) — original feature and UX specs
- [`docs/implementation-plan.md`](DailyFlightPlan/docs/implementation-plan.md) — phased build plan and progress
- [`docs/architecture.md`](DailyFlightPlan/docs/architecture.md) — folder structure, data models, services, UI direction

## The original idea

![Initial "back of a napkin" Figma sketch](DailyFlightPlan/docs/daily-flight-plan-figma.png)

## Concept

Combines one-off and recurring tasks, organized into time-of-day sections (Morning, Midday, Afternoon, Evening, Night). Items with specific deadlines appear as timed rows; items assigned to a section appear in a horizontal flow; items with no time at all land in an "Any Time" area at the bottom. A "now" bar tracks your current position in the day. Calendar events and Reminders from the system appear inline alongside your own tasks.

## Tech stack

- **SwiftUI + Liquid Glass** — primary UI framework with iOS 26 glass effects
- **SwiftData** — local persistence (iCloud sync planned)
- **EventKit** — Calendar and Reminders integration
- **SwiftUI-Flow** (`HFlow`) — horizontal wrapping flow layouts for item pills
- **`@Observable @MainActor` ViewModels** — no Combine
- **Protocol-based services** injected via `@Environment` + `@Entry`

## Features (current)

- Day view with collapsible time-of-day sections
- Navigate between days with a directional slide animation
- "Go to today" button (appears only when you've navigated away)
- Add and edit items via a full-featured form (title, notes, flag, deadline, section, recurring days, categories)
- Swipe to cancel or defer an item to tomorrow; long-press for a context menu
- Recurring items with weekday picker
- Deadline-based items with clock-time rows
- "Any time" section for untimed items, including missed past-due items
- Scroll-to-now on appear
- Progress ring showing completed/total items for the day
- Filter bar: flagged, done, recurring, and category filters
- Category management (add, rename, delete)
- Theme switcher (Cupertino, 8-Bit, Kerby, Flamingo)
- Calendar events from EventKit shown inline in each day section
- Reminders from EventKit shown inline, with list color indicator; live-updates on store changes

## Project structure

```
DailyFlightPlan/
├── Common/              — App entry point, Environment.swift, service injection
├── Persistence/         — SwiftData models (PlanItem, PlanCategory, DaySection, ItemStatus)
├── Preferences/         — AppStorageKeys enum
├── Services/
│   ├── Calendar/        — CalendarService protocol + EventKit + mock
│   ├── Reminders/       — RemindersService protocol + EventKit + mock
│   └── Categories/      — CategorySelectionService
├── Theming/             — DFPTheme enum, ThemeViewModifier
└── Views/
    ├── Components/      — DaySectionView, ItemPillView, DeadlineItemRow, CalendarEventRow,
    │                      ReminderItemRow, NowBarView, ProgressRingView, CategoryCapsule
    ├── View Models/     — DayViewModel, ItemFormViewModel, CategoriesEditViewModel
    ├── DayView.swift
    ├── ItemForm.swift
    └── CategoriesEditView.swift
```

## Build plan

Phases 1–8 are complete. Remaining MVP phases:

| Phase | Description |
|-------|-------------|
| 9 | Settings (calendar/reminders toggles, calendar selection, day section boundaries) |
| 10 | Date picker (jump to any date) |
| 11 | Local notifications |
| 12 | Hands-on QA + Aviation UI spike |
| 13 | 1.0 Polish |
| 14 | Tech debt (unit tests, UI tests, architecture review) |

See [`docs/implementation-plan.md`](DailyFlightPlan/docs/implementation-plan.md) for full details including Version 2.0 and 3.0 plans.

## Building

Open `DailyFlightPlan/DailyFlightPlan.xcodeproj` in Xcode 26+, select a simulator or device, and run. No additional setup required — SwiftUI-Flow is fetched via Swift Package Manager.
