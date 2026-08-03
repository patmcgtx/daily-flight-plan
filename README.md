# Daily Flight Plan

A daily planning and execution app for iOS, inspired by an airplane flight plan checklist. Today is your trip; this is your checklist.

> "While we delay, life hurries past."
> — Seneca

See this app's plan [plan and progress](DailyFlightPlan/docs/implementation-plan.md).


## Goals

Most people already know how to plan their day. The hard part is actually executing it — staying aware of what you committed to, not losing track of things as time passes, and finishing with a real sense of completion rather than just motion.

Daily Flight Plan is about execution, not planning. It's a lightweight layer on top of your existing Calendar and Reminders — not a replacement — that gives your day clear structure and focuses your attention on what matters right now.

**Design principles:**
- **One day at a time.** The app lives in today. Past and future are reference, not focus.
- **Present, not just planned.** The goal isn't just to have a list — it's to stay aware and present as the day unfolds.
- **Fast and out of your way.** Checking off and adding items should take seconds, not decisions.
- **Calm, not urgent.** Time-of-day sections create structure without adding pressure.
- **Context on your terms.** Calendar events and Reminders appear inline for full context, but can be toggled off instantly when you need to narrow your focus to just your own plan.
- **Finishing feels good.** Progress is always visible; completing your plan feels like landing the plane.

**Version 1.0 target:** A personal daily-use tool that integrates cleanly with Calendar and Reminders, works great on iPhone, and is good enough to ship. iPad, Watch, iCloud sync, and Siri come later.

## The original idea

I took an app idea in my mind, sketched it out in Figma, broke that into a detailed requirements spec, and fed that to a Claude agent to make an architecture and a plan.

- [`docs/project-spec-prompt.md`](DailyFlightPlan/docs/project-spec-prompt.md) — original feature and UX specs
- [`docs/architecture.md`](DailyFlightPlan/docs/architecture.md) — folder structure, data models, services, UI direction
- [`docs/implementation-plan.md`](DailyFlightPlan/docs/implementation-plan.md) — phased build plan and progress

![Initial "back of a napkin" Figma sketch](DailyFlightPlan/docs/daily-flight-plan-figma.png)

## Concept

Combines one-off and recurring tasks, organized into time-of-day sections (Morning, Midday, Afternoon, Evening, Night). Items with specific deadlines appear as timed rows; items assigned to a section appear in a horizontal flow; items with no time at all land in an "Any Time" area at the bottom. A "now" bar tracks your current position in the day. Calendar events and Reminders from the system appear inline alongside your own tasks. Sections whose time has passed are removed from view; their content is reorganized into "Past" (calendar events), "Missed" (deadline items and timed reminders), and "Any Time" (untimed items). Navigate to a future date to see a ghosted preview of your expected recurring habits.

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
- Scroll-to-now on appear
- Progress ring showing completed/total items for the day
- Filter bar: flagged, done, recurring, and category filters
- Category management (add, rename, delete)
- Theme switcher (Cupertino, 8-Bit, Kerby, Flamingo)
- Calendar events from EventKit shown inline in each day section
- Reminders from EventKit shown inline, with list color indicator; live-updates on store changes
- **Spillover**: pending items from previous days automatically move to today on launch or at midnight
- **Live day structure**: past sections disappear in real time as their time window ends; their content redistributes into "Past" (calendar events), "Missed" (deadline items + timed reminders), and "Any Time" (untimed/section-missed items)
- **Future date preview**: recurring habits for a future weekday appear ghosted in their section — not yet committed, just a projection

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

Phases 1–9 are complete. Remaining MVP phases:

| Phase | Description |
|-------|-------------|
| 10 | UI refinements (drag to reorder, calendar/reminders toggles, visual polish) |
| 11 | Timeline view |
| 12 | Nav & chrome rework (swipe days, bottom glass bar) |
| 13 | Quick entry (natural language → PlanItem via Foundation Models) |
| 14 | Search |
| 15 | Settings (calendar/reminders selection, section boundaries) |
| 16 | Local notifications |
| 17 | Usability testing |
| 18 | Fit and finish + Aviation UI spike |
| 19 | Tech debt (unit tests, UI tests, architecture review) |

See [`docs/implementation-plan.md`](DailyFlightPlan/docs/implementation-plan.md) for full details including Version 2.0 and 3.0 plans.

## Building

Open `DailyFlightPlan/DailyFlightPlan.xcodeproj` in Xcode 26+, select a simulator or device, and run. No additional setup required — SwiftUI-Flow is fetched via Swift Package Manager.
