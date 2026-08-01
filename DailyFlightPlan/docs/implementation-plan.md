# Implementation Plan

See `architecture.md` for folder structure, data models, and UI direction.

## ✅ Phase 1 — Skeleton + Models
- Set up folder structure mirroring MapsPlus
- Copy and rename `Theming/` from MapsPlus (`MapPlusTheme` → `DFPTheme`)
- Copy `Common/Environment.swift` pattern
- Create `AppStorageKeys` enum
- Define `PlanItem`, `PlanCategory`, `DaySection`, `ItemStatus` SwiftData models
- Create `ModelContainers` factory (persistent + in-memory for previews)
- Remove Xcode template boilerplate (`Item.swift`, placeholder `ContentView`)
- Add SwiftUI-Flow package dependency

## ✅ Phase 2 — Day View (read-only)
- `DayViewModel` — computes sections, filters items, tracks selected date
- `DayView` — sticky header (date nav, filter row stub), scrollable section cards
- `DaySectionView` — collapsible rounded-rect card
- `ItemPillView` — day-section item pill (HFlow layout)
- `DeadlineItemRow` — deadline item row (clock icon, formatted time, title)
- `NowBarView` — red line placed in the correct section
- "Any time" section at bottom (no border)
- Scroll-to-now on appear
- SwiftUI previews with in-memory sample data
- Theme menu wired up (`@AppStorage`, applied at root via `ThemeViewModifier`)
- "Go to today" button (`scope` icon, visible only when not on today)
- Directional slide animation on day navigation (< / > / scope)

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

## Phase 5 — Filtering + Categories
- Wire up filter toggle pills (flagged / completed / recurring) to `@AppStorage`
- Horizontally scrollable `CategoryCapsule` row in filter sub-bar
- `CategorySelectionService` (adapted from MapsPlus)
- `CategoriesEditView` for adding/editing categories

## Phase 6 — Progress Indicator
- `ProgressRingView` — small donut/ring in header top-right
- Computed from: completed / (total non-canceled items for today)
- Color changes with completion ratio (green → yellow → red)

## Phase 7 — Calendar Integration
- `CalendarService` protocol + `EventKitCalendarService` live implementation
- `MockCalendarService` (#if DEBUG)
- EventKit permission request on first launch
- Let user select which calendars to show (stored in `@AppStorage`); UI in Settings
- Display `CalendarEvent` rows in day sections for selected calendars only
- Tap to open Calendar app

## Phase 8 — Reminders Integration
- `RemindersService` protocol + `EventKitRemindersService` live implementation (shares `EKEventStore` with CalendarService)
- `MockRemindersService` (#if DEBUG)
- Request Reminders permission (`EKEntityType.reminder`) separately from Calendar permission
- Let user select which Reminders lists to sync (stored in `@AppStorage`); UI in Settings
- Add `reminderIdentifier: String?` to `PlanItem` to track origin (preserves option for two-way sync)
- Display synced reminders as native `PlanItem`s in the day view (not a separate row type)
- **TBD**: two-way completion sync — marking complete/canceled could write back to `EKReminder.isCompleted`; deferring could update `EKReminder.dueDateComponents`. Decide when we get here.

## Phase 9 — Settings Placeholder
- `SettingsView` stub (empty, navigated to from ⚙ button)
- Placeholder text: "Customization coming soon"

## Phase 10 — Date Picker
- Implement the `calendar.circle` date-picker placeholder in the header
- Let the user jump to any date directly (not just ±1 day)

## Phase 11 — Customizable Day Sections
- `SettingsView` section for editing day section time boundaries
- Store custom start/end hours in `@AppStorage` (or SwiftData)
- `DaySection.containing(_:)` reads from stored boundaries instead of hardcoded values

## Phase 12 — Local Notifications
- Request notification permission on first use of a deadline item
- Schedule a `UNUserNotificationCenter` notification when a deadline item is saved
- Cancel/reschedule notifications when item is edited, completed, canceled, or deferred
- Notification times respect custom day section boundaries from Phase 11

## Phase 13 — Aviation UI Experiment
- Explore a dedicated "flight plan" visual style beyond color themes — e.g. monospace/typewriter fonts, cockpit-dark palette, section headers styled like flight log table rows, checklist-style item rendering
- Could be a new `DFPTheme` case, a separate `UIStyle` dimension orthogonal to color theme, or a full alternate view mode. Possibly something retro like "TWA" or "Pan Am"
- Don't overdo it, or at least make it optional.
- Treat as a design spike: prototype freely, keep what feels right, discard the rest

## Phase 14 — iPad Support
- Adopt adaptive layout using `horizontalSizeClass` — on regular width, consider a two-column split (e.g. date/section list on left, day detail on right)
- Verify `HFlow` pill layouts scale well on wider screens
- Keyboard navigation and hardware keyboard shortcuts (arrow keys to navigate days, etc.)
- Test with Stage Manager and multitasking split views
- Pointer/cursor hover states for trackpad users

## Phase 15 — Mac Support
- Enable Mac Catalyst or SwiftUI native Mac target
- Replace glass pill buttons and swipe gestures with Mac-native equivalents (context menus, toolbar buttons)
- Menu bar integration: keyboard shortcuts for common actions (new item, next/previous day, go to today)
- Appropriate window minimum size and resizable layout
- Test full keyboard navigation and VoiceOver on macOS

## Phase 16 — Widget + Live Activity
- Home screen widget: show today's next upcoming item or a compact progress ring + item count
- Lock screen widget: minimal glanceable version (next item, section, time)
- Live Activity (Dynamic Island + Lock Screen): show the current/next item during the day, update as items are completed
- Uses `WidgetKit` + `ActivityKit`; shares SwiftData read access via App Group container

## Phase 17 — Apple Watch App
- Companion Watch app showing today's items in a scrollable list
- Complication showing progress ring or next item title
- Tap to complete items directly from the wrist
- Syncs via Watch Connectivity (`WCSession`) or shared CloudKit container (depends on iCloud sync status)
- Keep it read + complete only; add/edit stays on iPhone

## Phase 18 — iCloud Sync
- Enable CloudKit capability in entitlements
- Switch `ModelConfiguration` to use a CloudKit container identifier
- Handle merge conflicts and sync errors gracefully
