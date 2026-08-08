# Daily Flight Plan

A daily planning and execution app for iOS, inspired by an airplane flight plan checklist. Today is your trip; this is your checklist.

> "While we delay, life hurries past."
> — Seneca

See this app's [plan and progress](DailyFlightPlan/docs/implementation-plan.md).


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

Combines one-off and recurring tasks, organized into five time-of-day sections (Morning, Midday, Afternoon, Evening, Night). Items with specific deadlines appear as timed rows; items assigned to a section appear in a horizontal flow; items with no time at all land in an "Open" area at the bottom. A "now" bar tracks your current position in the day. Calendar events and Reminders from the system appear inline alongside your own tasks. All five sections are always visible — past sections stay on screen as a day-at-a-glance reference. Inactive sections auto-collapse with a one-line AI summary; items past a specific deadline surface in a "Missed" area. Navigate to a future date to see a ghosted preview of your expected recurring habits.

## Tech stack

- **SwiftUI + Liquid Glass** — primary UI framework with iOS 26 glass effects
- **SwiftData** — local persistence (iCloud sync planned)
- **EventKit** — Calendar and Reminders integration
- **SwiftUI-Flow** (`HFlow`) — horizontal wrapping flow layouts for item pills
- **`@Observable @MainActor` ViewModels** — no Combine
- **Protocol-based services** injected via `@Environment` + `@Entry`

## Features (current)

- Day view with five collapsible time-of-day sections — all always visible, including past sections for day-at-a-glance reference
- **Auto-collapse + AI summary**: inactive sections collapse automatically; collapsed headers show a one-line on-device AI summary (Foundation Models)
- **Grouped item sub-rows**: pending pills → Done row (✓) → Cancelled row (✗) → Habits row (∞ recurring); completed and cancelled items show with strikethrough
- Navigate between days with a directional slide animation
- "Go to today" button (appears only when you've navigated away)
- Add and edit items via a full-featured form (title, notes, flag, deadline, section, recurring days, categories)
- Long-press any item for a context menu: cancel, defer to tomorrow, edit
- Drag-and-drop items between day sections; drop on "Open" to clear section assignment
- Recurring items with weekday picker; grouped on a dedicated Habits row
- Deadline-based items with clock-time rows; missed deadlines surface in a "Missed" area
- Scroll-to-now on appear; live clock auto-expands the current section as the day progresses
- Progress ring showing completed/total items for the day
- Filter bar: flagged, done, calendar, reminders, and category filters
- Category management (add, rename, delete)
- Theme switcher (Cupertino, 8-Bit, Kerby, Flamingo)
- Calendar events from EventKit shown inline in each day section
- Reminders from EventKit shown inline, with list color indicator; live-updates on store changes
- **Spillover**: pending items from previous days automatically move to today on launch or at midnight
- **Future date preview**: recurring habits for a future weekday appear ghosted in their section — not yet committed, just a projection
- **Timeline sheet**: all plan items grouped by date with filter bar; tap a date or row to navigate DayView

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
    ├── TimelineView.swift
    ├── ItemForm.swift
    └── CategoriesEditView.swift
```

## Build plan

Phases 1–13 are complete. Remaining MVP phases:

| Phase | Description |
|-------|-------------|
| 14 | Usability Part 2 (in progress) |
| 15 | Fix recurring items / habits behavior |
| 16 | Finish timeline view (lazy-load, full history + future) |
| 17 | Brand new focus view |
| 18 | Architecture clean up |
| 19 | Chat / quick entry (natural language → PlanItem via Foundation Models) |
| 20 | Search |
| 21 | Settings (calendar/reminders selection, section boundaries) |
| 22 | Local notifications |
| 23 | Smooth day swipe navigation (pager) |
| 24 | Fit and finish + aviation UI spike |
| 25 | Tech debt (unit tests, UI tests, architecture review) |

See [`docs/implementation-plan.md`](DailyFlightPlan/docs/implementation-plan.md) for full details including Version 2.0 and 3.0 plans.

## Building

Open `DailyFlightPlan/DailyFlightPlan.xcodeproj` in Xcode 26+, select a simulator or device, and run. No additional setup required — SwiftUI-Flow is fetched via Swift Package Manager.
