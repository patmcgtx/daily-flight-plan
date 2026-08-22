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

**Version 1.0 target:** A personal daily-use tool that integrates cleanly with Calendar and Reminders, works great on iPhone and Mac (via iCloud sync), and is good enough to ship. iPad, Watch, and Siri come later.

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

**Four tabs:**

- **Day** — primary day view (Flight Plan) with swipe-between-days pager
  - Swipe left/right to navigate days (iOS: `TabView(.page)` pager; macOS: drag gesture)
  - "Today" label in accent color; `scope` go-to-today button on non-today dates
  - Collapsible section cards with per-section progress ring (`completed/total`, filter-independent)
  - `HFlow` pills for non-deadline items (regular items and routine items on separate rows); timed rows for deadline items
  - Notes indicator icon on pills when notes are populated
  - Calendar events and Reminders shown inline in expanded section cards
  - Drag-and-drop items between section cards; drop on Open card to clear section assignment
  - Filter-driven expand/collapse: active filters auto-expand sections with matches

- **Log** — chronological multi-day list
  - Shows all plan items across all dates with a filter bar
  - Fully interactive: checkbox completes, tap to edit, long-press for cancel

- **Routine** — recurring habit template management
  - Collapsible cards grouped by weekday pattern: Every Day, Weekdays, Weekends, plus any custom patterns (e.g. Mon/Wed/Fri)
  - Tap a card header to expand/collapse; collapsed state shows section name and item count
  - Each card subdivided by day segment (First Thing, Morning, …); timed items get their own row, untimed items flow as `HFlow` pills
  - Tap any item to edit; long-press for Edit / Delete context menu
  - Drag items between cards to reassign their weekday pattern
  - Add custom sections via a weekday picker; delete sections (severs templates from historical instances)

- **Comm** — placeholder for future AI chat / natural language quick entry

**macOS keyboard shortcuts:** `Cmd+1` Day · `Cmd+2` Log · `Cmd+3` Routine · `Cmd+4` Comm

**Shared across tabs:**
- Add and edit items via a full-featured form (title, notes, flag, deadline, section, recurring days, categories)
- Long-press any item for a context menu: cancel, defer to tomorrow, edit
- Recurring habit templates with weekday picker; per-day instances materialized lazily
- Deadline-based items with clock-time rows; missed deadlines surface in a "Missed" area
- Filter menu: flagged, done, calendar, reminders, routines, and category filters
- **Markdown / text import**: paste any text (e.g. a Things export) → Foundation Models parses titles, sections, and recurring schedules → review list with swipe-to-delete → commit or cancel
- Category management (add, rename, delete)
- Theme switcher (Cupertino, 8-Bit, Kerby, Flamingo)
- Calendar events from EventKit shown inline, with calendar color indicator
- Reminders from EventKit shown inline, with list color indicator; live-updates on store changes
- **Spillover**: pending items from previous days automatically move to today on launch or at midnight
- **Future date preview**: recurring habits for a future weekday appear ghosted in their section
- iCloud sync via CloudKit (plan on Mac, execute on iPhone)

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
    ├── DayView.swift          — TabView host; manages shared state, fetches calendar/reminders
    ├── FlightPlanView.swift   — Flight Plan tab (primary day view, swipe pager)
    ├── RoutineView.swift      — Routine tab (recurring habit template management)
    ├── MarkdownImportView.swift — Paste-to-import sheet; Foundation Models structured parsing
    ├── CardDeckView.swift     — Cards tab (commented out)
    ├── TimelineView.swift     — Nav Log tab
    ├── ItemForm.swift
    └── CategoriesEditView.swift
```

## Build plan

Phases 1–21 are complete. Up next:

| Phase | Description |
|-------|-------------|
| 22 | Chat / quick entry (natural language → PlanItem via Foundation Models) |
| 23 | Finish Nav Log (lazy-load, full history + future, search) |
| 24 | Finish Day / Flight view |
| 25 | Settings (calendar/reminders selection, section boundaries) |
| 26 | Local notifications |
| 28 | Fit and finish + aviation UI spike |
| 29 | Tech debt (unit tests, UI tests, architecture review) |
| 30 | Beta testing |

See [`docs/implementation-plan.md`](DailyFlightPlan/docs/implementation-plan.md) for full details including Version 2.0 and 3.0 plans.

## Building

Open `DailyFlightPlan/DailyFlightPlan.xcodeproj` in Xcode 26+, select a simulator or device, and run. No additional setup required — SwiftUI-Flow is fetched via Swift Package Manager.
