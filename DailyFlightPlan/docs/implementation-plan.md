# Implementation Plan

See `architecture.md` for folder structure, data models, and UI direction.

## Version 1.0

### ✅ Phase 1 — Skeleton + Models
- Set up folder structure mirroring MapsPlus
- Copy and rename `Theming/` from MapsPlus (`MapPlusTheme` → `DFPTheme`)
- Copy `Common/Environment.swift` pattern
- Create `AppStorageKeys` enum
- Define `PlanItem`, `PlanCategory`, `DaySection`, `ItemStatus` SwiftData models
- Create `ModelContainers` factory (persistent + in-memory for previews)
- Remove Xcode template boilerplate (`Item.swift`, placeholder `ContentView`)
- Add SwiftUI-Flow package dependency

### ✅ Phase 2 — Day View (read-only)
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

### ✅ Phase 3 — Item Interactions
- Completion checkbox (toggle `.completed`)
- Swipe left → cancel; swipe right → defer to tomorrow
- Long-press menu: cancel / defer / edit
- Missed item logic: past-due `.pending` items move to "any time" area with orange/red tint
- Struck-through deadline on missed items

### ✅ Phase 4 — Filtering + Categories
- Wire up filter toggle pills (flagged / completed / recurring) to `@AppStorage`
- Horizontally scrollable `CategoryCapsule` row in filter sub-bar
- `CategorySelectionService` (adapted from MapsPlus) — SwiftData-backed `SelectedCategories` singleton
- `CategoriesEditView` + `CategoriesEditViewModel` for adding/renaming/deleting categories
- `@Environment(\.categorySelectionService)` injected via `InjectLiveServicesModifier` / `InjectMockServicesModifier`
- Filter toggles show active state (accentColor fill) vs. inactive (regularMaterial)
- Follow-up polish: recurring items remain visible by default, add/rename/delete category actions now only clear UI state after a successful SwiftData save, and category item counts pluralize correctly

### ✅ Phase 5 — Progress Indicator
- `ProgressRingView` — small donut/ring in header top-right
- Computed from: completed / (total non-canceled items for today)
- Color transitions red → yellow → green via HSB hue sweep as progress increases
- Animates with spring when completion changes

### ✅ Phase 6 — Add / Edit Item
- `ItemForm` sheet with: title, notes, flagged toggle, date + optional deadline time, recurring toggle + day-of-week picker, category selector
- `ItemFormViewModel` (`@Observable @MainActor`)
- Validate and save via `modelContext`; both create and edit modes
- Edit triggered via `@Entry var editItem` environment key injected by `DayView`; "Edit…" context menu item in `ItemPillView` and `DeadlineItemRow` calls it
- Add Item button in `DayView` presents `ItemForm(date:)`; "Edit…" presents `ItemForm(item:)`
- Bindings use `Bindable(viewModel).property` pattern since ViewModel is `@Observable @MainActor`

### ✅ Phase 7 — Calendar Integration
- `CalendarService` protocol + `EventKitCalendarService` live implementation (EventKit full access)
- `MockCalendarService` (#if DEBUG) — returns mock events for today only
- `CalendarEvent` and `CalendarInfo` DTOs in `Services/Calendar/`
- Permission requested on first event fetch in `DayView.fetchCalendarEvents()`
- `NSCalendarsFullAccessUsageDescription` added to `Info.plist`
- `selectedCalendarIDs` added to `AppStorageKeys` (comma-separated; empty = all calendars)
- `CalendarEventRow` — read-only row with colored calendar dot; tap opens Calendar app via `calshow:` URL
- Calendar events rendered in each `DaySectionView` (below deadline rows) via `calendarEventsForSection(_:from:)` on `DayViewModel`
- Calendar selection UI deferred to Phase 9 (Settings); all calendars shown by default

### ✅ Phase 8 — Reminders Integration
- `RemindersService` protocol + `EventKitRemindersService` live implementation (separate `EKEventStore` from calendar service)
- `MockRemindersService` (#if DEBUG) — returns two mock items for today: one timed, one undated
- Reminders permission requested lazily on first fetch (`requestFullAccessToReminders()`, iOS 17+)
- `NSRemindersFullAccessUsageDescription` added to `Info.plist`
- `selectedReminderListIDs` added to `AppStorageKeys` (comma-separated; empty = all lists)
- `reminderIdentifier: String?` added to `PlanItem` for future two-way sync tracking
- `ReminderItemRow` — read-only row with list color dot + bell icon + optional time + title
- Timed reminders appear in their matching day section (via `reminderItemsForSection(_:from:)` on `DayViewModel`)
- Undated reminders appear in the "Any Time" area as a grouped card of `ReminderItemRow`s
- `EKEventStoreChanged` notification re-fetches both calendar events and reminders on any store change
- **Deferred**: two-way completion sync (marking done/deferred writing back to `EKReminder`) — decide in a later phase
- **Deferred**: reminder list selection UI — moved to Phase 9 (Settings)

### ✅ Phase 9 — Workflow Refinements
- **Spillover**: On app launch (and at midnight if the app is open), pending items from any date before today are moved to today. Deadline-based items have their deadline cleared and become "any time" items (already flagged as missed). Recurring items spill as-is (no duplicate created for the new day). Navigation moves to today after spill.
- **"Past" section**: When viewing today, sections whose time window has already ended are hidden from the main section list. Their past calendar events appear in a non-section "Past" area at the top of the scroll view. Pending plan items from those sections appear in the "Any Time" area via the missed-item logic. Timed reminders from past sections appear in the "Missed" area.
- **"Missed" section**: Dedicated non-section area (above "Any Time") for pending items whose specific deadline has passed and for past timed reminders. Uses `DeadlineItemRow` to show the missed time.
- **"Any Time" split**: Untimed items and section-based items whose section has ended (but had no specific deadline) appear in "Any Time". Deadline-missed items moved to "Missed".
- **Live clock**: A per-minute timer drives `currentSection` and `activeSections` so the Past/Missed areas grow in real time as sections end during the day.
- **Projected recurring items**: On future dates, recurring section-based habits that apply to that weekday appear as ghosted (35% opacity, non-interactive) pills in their section — a preview of the expected day, not yet committed items.
- **Richer seed data**: Recurring habits across all five sections (coffee, journal, run, standup, clear inbox, gym, walk, read, plan tomorrow) plus one-off items and untimed tasks.
- **Deferred**: Drag to reorder items between sections → Phase 10

### Phase 10 — UI Refinements
- ✅ **Drag to reassign section**: Long-press any section pill or deadline row to drag it to a different day section card. Dropping onto a section sets `item.daySection` and clears any deadline. Dragging to "Open" clears both (`daySection = nil`, `deadline = nil`). Each section highlights with an accent-colored border while a drag is over it. Added `uuid: UUID` to `PlanItem` as a stable drag token. "Open" also acts as a drop target, with an empty placeholder shown when it has no items.
- ✅ **Calendar / Reminders toggles**: Filter-bar `Calendar` and `Reminders` toggle pills added to the filter row (stored in `@AppStorage` as `showCalendarEvents` / `showReminderItems`, both on by default). When toggled off, events/reminders are hidden from all sections, Past, Missed, and Open.
- Make Reminders items and Calendar events stand out more (or less) from the rest of the items, such as italic font.
- Make recurring items, aka habits, stand out in some more intuitive way as well. I like the infinity icon. Maybe just lay it out differently?
- ✅ Renamed "Any Time" → "Open" (works for today and all other dates)

### ✅ Phase 11 — Timeline view
- `TimelineView.swift` — plan items only (no Calendar events, no Reminders)
- Filter bar with Flagged/Done/Recurring toggles + category capsules (same `@AppStorage` keys as DayView)
- Items grouped by date (`Dictionary(grouping:)` → sorted by day); today is always shown even if empty after filtering
- "Today" section header uses accent color + bold; past dates are dimmed; future dates are full-weight
- `ScrollViewReader` scrolls to today's section on `.onAppear`
- Row shows status icon (checkmark/circle/x), title with strikethrough for done/canceled, and a subtitle showing deadline time or day section name
- Tapping any row or the date header dismisses the sheet and calls `viewModel.navigate(to: date)` in DayView
- Timeline button (`calendar.day.timeline.left`) added to DayView header (left side, next to `[<]`)
- `navigate(to:)` method added to `DayViewModel`
- Read-only; add/edit deferred to a later phase

### Phase 12 — Search
- Search bar (`.searchable`) in the day view header or as a dedicated screen
- Search across all items (title, notes) regardless of date
- Results grouped by date, showing section and status
- Tapping a result navigates to that day and scrolls to the item
- Filter results by status (pending / completed / canceled)

### Phase 13 — Quick Entry (Natural Language)
- Replace (or augment) the "Add Item" button with a free-text entry field — a compact text bar that stays visible or slides up
- User types natural language: "Call dentist tomorrow at 2pm", "Run every weekday morning", "Buy milk — flagged"
- On submit, pass the raw text to **Apple Foundation Models** (`FoundationModels` framework, on-device) using a `@Generable` struct for structured output:
  - `title: String`
  - `notes: String?`
  - `date: String?` (relative, e.g. "tomorrow", "next Monday" — resolved to `Date` post-generation)
  - `deadlineTime: String?` (e.g. "2pm")
  - `daySection: String?` (e.g. "morning", "evening")
  - `isRecurring: Bool`
  - `recurringWeekdays: [String]?`
  - `isFlagged: Bool`
- Resolve relative date strings to concrete `Date` values after generation
- Create and save a `PlanItem` from the structured output, applying it to the current day (or the parsed date if explicit)
- Show a brief inline confirmation row (the created item) after each submission, allowing the user to keep entering more items — repeat until dismissed
- Fall back gracefully if Foundation Models is unavailable (device too old, OS < 26): show a toast and open `ItemForm` instead
- Full `ItemForm` remains available via a detail button on the confirmation row for tweaks

### Phase 14 — Settings
- `SettingsView` navigated to from ⚙ button
- **Calendar settings**: toggle to enable/disable calendar event display; multi-select list of available calendars (uses `CalendarService.availableCalendars()` + `AppStorageKeys.selectedCalendarIDs`; empty = all)
- **Reminders settings**: similar toggle + list picker for reminder lists
- **Day section boundaries**: edit start/end hours for each day section; store in `@AppStorage`; `DaySection.containing(_:)` reads from stored values instead of hardcoded hours
- Any other preferences surfaced here as phases are completed

### Phase 15 — Local Notifications
- Request notification permission on first use of a deadline item
- Schedule a `UNUserNotificationCenter` notification when a deadline item is saved
- Cancel/reschedule notifications when item is edited, completed, canceled, or deferred
- Notification times respect custom day section boundaries from Phase 14

### Phase 16 — Usability Testing
- Use the app daily for a real period of time — real tasks, real calendar events, real reminders
- Note friction points, readability issues, missing features, visual rough edges, and anything that feels off in actual use
- Gather a prioritized list of changes needed before shipping version 1.0
- Possibly rework horizontal/vertical dragging to drag-anywhere and show "buckets" to cancel or defer.
  Drqagging to/from sections would remain like it its.

### Phase 17 — Fit and Finish
- Address findings from Phase 16 usability testing
- Bug fixes, UX tweaks, visual polish
- **Readability & accessibility**: Dynamic Type support across all text styles; VoiceOver labels on interactive elements (pills, rows, filter toggles, progress ring); minimum tap target sizes; sufficient color contrast in all themes; test with Accessibility Inspector
- **Completion celebration**: when the last pending item is checked off for the day, trigger a reward moment — confetti burst or similar animation, progress ring transforms into a large checkmark (or full green fill), brief haptic feedback
- **Aviation UI spike**: explore a "flight plan" visual style — monospace/typewriter fonts, cockpit-dark palette, section headers styled like flight log rows, checklist-style rendering. Could be a new `DFPTheme` case or a separate `UIStyle` dimension. Prototype freely; keep what feels right, discard the rest. Findings feed into Version 3.0 planning.
- **Localization**: wrap all user-visible strings in `String(localized:)` or `LocalizedStringKey`; add a base `Localizable.xcstrings` catalog; verify date/time formatting uses locale-aware formatters (already done via `.dateTime` format style)
- Add an app icon
- Anything that must be right before calling this version 1.0

### Phase 18 — Tech debt
- Architecture review & refactor
- Unit tests (Swift Testing framework): `DayViewModel`, `ItemFormViewModel`, `CategoriesEditViewModel`, `CategorySelectionService`, `DaySection`, `CalendarService`, `RemindersService`
- UI tests (XCUIAutomation): core flows — add item, complete item, cancel/defer item, navigate days, open settings

---

## Version 2.0

### iCloud Sync
- Enable CloudKit capability in entitlements
- Switch `ModelConfiguration` to use a CloudKit container identifier
- Handle merge conflicts and sync errors gracefully


### Import / Export
- Export a day or the timeline view
- Import (ideally from Things as) probably from markdwon like DayOne does, possibly local AI-assisted

### iPad Support
- Adopt adaptive layout using `horizontalSizeClass` — on regular width, consider a two-column split (e.g. date/section list on left, day detail on right)
- Verify `HFlow` pill layouts scale well on wider screens
- Keyboard navigation and hardware keyboard shortcuts (arrow keys to navigate days, etc.)
- Test with Stage Manager and multitasking split views
- Pointer/cursor hover states for trackpad users

### Mac Support
- Enable Mac Catalyst or SwiftUI native Mac target
- Replace glass pill buttons and swipe gestures with Mac-native equivalents (context menus, toolbar buttons)
- Menu bar integration: keyboard shortcuts for common actions (new item, next/previous day, go to today)
- Appropriate window minimum size and resizable layout
- Test full keyboard navigation and VoiceOver on macOS

---

## Version 3.0

### Siri & AI
- Support Siri for adding items and asking specific questions 
- Opt into iOS AI support so Siri can knwo about my daily plan


### Widget + Live Activity
- Home screen widget: show today's next upcoming item or a compact progress ring + item count
- Lock screen widget: minimal glanceable version (next item, section, time)
- Live Activity (Dynamic Island + Lock Screen): show the current/next item during the day, update as items are completed
- Uses `WidgetKit` + `ActivityKit`; shares SwiftData read access via App Group container

### Apple Watch App
- Companion Watch app showing today's items in a scrollable list
- Complication showing progress ring or next item title
- Tap to complete items directly from the wrist
- Syncs via Watch Connectivity (`WCSession`) or shared CloudKit container (depends on iCloud sync status)
- Keep it read + complete only; add/edit stays on iPhone
