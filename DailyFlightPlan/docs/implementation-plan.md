# Implementation Plan

See `architecture.md` for folder structure, data models, and UI direction.

## Phase 1 — Skeleton + Models
- Set up folder structure mirroring MapsPlus
- Copy and rename `Theming/` from MapsPlus (`MapPlusTheme` → `DFPTheme`)
- Copy `Common/Environment.swift` pattern
- Create `AppStorageKeys` enum
- Define `PlanItem`, `PlanCategory`, `DaySection`, `ItemStatus` SwiftData models
- Create `ModelContainers` factory (persistent + in-memory for previews)
- Remove Xcode template boilerplate (`Item.swift`, placeholder `ContentView`)
- Add SwiftUI-Flow package dependency

## Phase 2 — Day View (read-only)
- `DayViewModel` — computes sections, filters items, tracks selected date
- `DayView` — sticky header (date nav, filter row stub), scrollable section cards
- `DaySectionView` — collapsible rounded-rect card
- `ItemRow` — deadline item row (checkbox placeholder, clock icon, title)
- `CategoryCapsule` — day-section item pill (adapted from MapsPlus)
- `NowBar` — red line placed in the correct section
- "Any time" section at bottom (no border)
- Scroll-to-now on appear
- SwiftUI previews with in-memory sample data

## Phase 3 — Item Interactions
- Completion checkbox (toggle `.completed`)
- Swipe left → cancel; swipe right → defer to tomorrow
- Long-press menu: cancel / defer / edit
- Missed item logic: past-due `.pending` items move to "any time" area with orange/red tint
- Struck-through deadline on missed items

## Phase 4 — Add / Edit Item
- `ItemForm` sheet with: title, notes, flagged toggle, date + optional deadline time, recurring toggle + day-of-week picker, category selector
- `ItemFormViewModel`
- Validate and save via `modelContext`
- Mock service + preview

## Phase 5 — Calendar Integration
- `CalendarService` protocol + `EventKitCalendarService` live implementation
- `MockCalendarService` (#if DEBUG)
- EventKit permission request on first launch
- Display `CalendarEvent` rows in day sections
- Tap to open Calendar app

## Phase 6 — Filtering + Categories
- Wire up filter toggle pills (flagged / completed / recurring) to `@AppStorage`
- Horizontally scrollable `CategoryCapsule` row in filter sub-bar
- `CategorySelectionService` (adapted from MapsPlus)
- `CategoriesEditView` for adding/editing categories

## Phase 7 — Progress Indicator
- `ProgressRingView` — small donut/ring in header top-right
- Computed from: completed / (total non-canceled, non-deferred items for today)
- Color changes with completion ratio (green → yellow → red)

## Phase 8 — Settings Placeholder
- `SettingsView` stub (empty, navigated to from ⚙ button)
- Placeholder text: "Customization coming soon"
