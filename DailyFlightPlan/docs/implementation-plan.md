# Implementation Plan

See `architecture.md` for folder structure, data models, and UI direction.

See `ux-improvements.md` for a running list of UX/workflow improvement ideas with notes, to be triaged into phases below.

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
- **Richer seed data**: Recurring habits across all six sections plus timed and untimed items for thorough testing.
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
- **Deferred**: lazy-load past days — moved to Phase 12

### ✅ Phase 12 — Usability Part 1
Items identified during early real-world use.

- **Remove the Recurring filter toggle**: always show recurring items; grouped habit row makes them easy to distinguish visually
- **Auto-hide completed Reminders**: treat completed reminders the same as completed plan items — hidden unless the Done filter is active
- **Hide past Calendar events**: treat past-section calendar events as done; hide by default, show only if Done filter is active
- **Category filter excludes Calendar & Reminders**: when any category is selected, events and reminders are hidden entirely — they are not categorized
- **Time range on section headers**: display the actual hour range (e.g. "Morning · 6–10 AM") so there is no ambiguity about what each section covers
- **Tap item → edit**: a single short tap on any item pill or row opens its edit screen directly
- **Always show all five sections**: removed section hiding — past sections stay visible for day-at-a-glance reference; only deadline-missed items surface in the "Missed" area
- **Auto-collapse inactive sections + AI summary**: on today, all sections except the current one start collapsed; collapsed headers display a one-line AI summary generated via Foundation Models (`LanguageModelSession`); live clock tick auto-expands the incoming section; falls back to item count badge when Foundation Models is unavailable
- **Grouped item sub-rows**: pending pills → Done row (✓) → Cancelled row (✗) → Habits row (∞ recurring + ghost projections); completed and cancelled items show with strikethrough; per-pill ∞ badge suppressed in the Habits row; checkbox shown only on pending items

### Phase 13 — Nav & Chrome Rework (Liquid Glass)
- Remove `[<]` / `[>]` buttons from the header; replace with swipe-between-days on the scroll view background (horizontal drag gesture, background only — no conflict with item gestures once item swipes are retired)
- Retire swipe-left-to-cancel and swipe-right-to-defer on items; long-press context menu (already implemented) covers the same actions
- **Top header**: date only — large weekday + month/day centered; "Go to today" scope button inline when off today; tap date → date picker sheet
- **Bottom floating glass bar** (`safeAreaInset(edge: .bottom)`): `[<]` `[⏱ Timeline]` `[+]` `[···]` `[>]` — add item is the central prominent action; `···` menu contains settings, theme, categories
- **Move categories editing into `···` menu**: remove the separate tag icon from the filter row; "Manage Categories" lives in the dropdown alongside Settings and Theme
- Filter pills row stays sticky in the header
- **Progress indicator as floating button**: replace the inline progress summary row with a small floating donut button (bottom of screen, above the glass bar); tap it for a detail popover (X of Y complete, daily summary text)
- **Retire swipe gestures**: swipe-left-to-cancel and swipe-right-to-defer are too easy to trigger accidentally; replace with intentional drop targets (drag to a "Cancel" or "Defer" zone) or rely on long-press context menu only
- **Reserve space for Phase 14 (Quick Entry) and Phase 15 (Search)**: during this chrome rework, decide where the quick-entry bar and search live in the layout, and stub in placeholder UI elements so the nav structure doesn't need to be revisited again when those phases land. Quick entry likely replaces or augments the `[+]` button in the bottom bar; search likely lives in the top header or as a gesture.

### Phase 14 — Quick Entry (Natural Language)
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

### Phase 15 — Search
- Search bar (`.searchable`) in the day view header or as a dedicated screen
- Search across all items (title, notes) regardless of date
- Results grouped by date, showing section and status
- Tapping a result navigates to that day and scrolls to the item
- Filter results by status (pending / completed / canceled)

### Phase 16 — Settings
- `SettingsView` navigated to from ⚙ button
- **Calendar settings**: toggle to enable/disable calendar event display; multi-select list of available calendars (uses `CalendarService.availableCalendars()` + `AppStorageKeys.selectedCalendarIDs`; empty = all); if permission was denied or not yet granted, show a link to open Settings
- **Reminders settings**: similar toggle + list picker for reminder lists; same permission recovery link
- **Permission prompt on first filter tap**: when the user taps the Calendar or Reminders filter pill for the first time, prompt for permission then and there (rather than waiting for the day to load); on grant, show the calendar/list selector immediately
- **Day section boundaries**: edit start/end hours for each day section; store in `@AppStorage`; `DaySection.containing(_:)` reads from stored values instead of hardcoded hours; also update `DaySection.timeRangeLabel` to compute dynamically from stored boundaries instead of hardcoded strings
- **"Rise & Shine" pre-morning section**: consider adding an early-morning section (e.g. 5–6 AM) for first-thing-out-of-bed habits; or expose Morning's start time as a user-adjustable boundary so the section stretches to cover it
- **Rename "Night" → "Bedtime"**: or make section names user-editable alongside their time boundaries
- Any other preferences surfaced here as phases are completed

### Phase 17 — Local Notifications
- Request notification permission on first use of a deadline item
- Schedule a `UNUserNotificationCenter` notification when a deadline item is saved
- Cancel/reschedule notifications when item is edited, completed, canceled, or deferred
- Notification times respect custom day section boundaries from Phase 16

### Phase 18 — Usability Part 2
- Use the app daily for a real period of time — real tasks, real calendar events, real reminders
- Note friction points, readability issues, missing features, visual rough edges, and anything that feels off in actual use
- Gather a prioritized list of changes needed before shipping version 1.0
- Possibly rework horizontal/vertical dragging to drag-anywhere and show "buckets" to cancel or defer. Dragging to/from sections would remain like it is.
- **Timeline lazy-load past days**: start with today and load past days on demand as the user scrolls up, rather than fetching all history at once
- **Summary vs. full view**: reconsider the collapsed/expanded section toggle as a "summary vs. full" mode — the collapsed state could show a compact AI-generated summary card, and the expanded state shows the full item list. More flight-plan-like than a simple show/hide.
- **Import Reminder as PlanItem**: tapping a `ReminderItemRow` offers an "Import as Task" action that creates a `PlanItem` from the reminder's title, notes, and due date, then assigns it to the current day's appropriate section; the original reminder is left unchanged
- **"All clear ✅" for completed sections**: when a collapsed section has no remaining pending items (all done/cancelled or nothing), display "All clear ✅" in the header instead of an AI summary — a small reward for finishing the section
- **Day note area**: a freeform text field at the top of the day view for "what is today all about?" — a one-line intention or focus for the day; persisted per-date
- **AI summary quality**: weight timed/deadline items and non-recurring items more heavily in the summary prompt so the most time-sensitive things surface first

### Phase 19 — Fit and Finish
- Address findings from Phase 18 usability testing
- Bug fixes, UX tweaks, visual polish
- **Readability & accessibility**: Dynamic Type support across all text styles; VoiceOver labels on interactive elements (pills, rows, filter toggles, progress ring); minimum tap target sizes; sufficient color contrast in all themes; test with Accessibility Inspector. **Immediate concern: font sizes and contrast are too small/dim — prioritize this.**
- **Haptics**: `UIImpactFeedbackGenerator` on complete, cancel, and defer actions; `UINotificationFeedbackGenerator` on completion celebration
- **High contrast theme**: new `DFPTheme` case with larger text, stronger borders, and high-contrast color pairs
- **Completion celebration**: when the last pending item is checked off for the day, trigger a reward moment — confetti burst or similar animation, progress ring transforms into a large checkmark (or full green fill), brief haptic feedback
- **Aviation UI spike**: explore a "flight plan" visual style — monospace/typewriter fonts, cockpit-dark palette, section headers styled like flight log rows, checklist-style rendering. Could be a new `DFPTheme` case or a separate `UIStyle` dimension. Prototype freely; keep what feels right, discard the rest. Findings feed into Version 3.0 planning.
- **Localization**: wrap all user-visible strings in `String(localized:)` or `LocalizedStringKey`; add a base `Localizable.xcstrings` catalog; verify date/time formatting uses locale-aware formatters (already done via `.dateTime` format style)
- **Calendar/Reminders load delay on day switch**: noticeable lag when navigating to a new day because `fetchCalendarEvents()` and `fetchReminderItems()` are triggered by `.task(id: viewModel.selectedDate)` and run sequentially. Consider prefetching adjacent days, caching results, or showing a subtle loading state while data arrives.
- **Clean up seed data**: personal test habits in `ModelContainers.swift` must be removed or replaced with a minimal, generic example set before shipping
- **Drag-to-zone discoverability**: add a one-time tooltip or coach mark explaining the long-press drag gesture (Cancel zone lower-left, Defer zone lower-right) — most users won't discover it without a hint
- **Per-section add button**: consider a small `+` button on each section header (or in the section content area) so the user can add an item directly into that section without going through the main Add form and re-selecting the section
- Add an app icon
- Anything that must be right before calling this version 1.0

### Phase 20 — Tech debt
- Architecture review & refactor
- **`DaySectionView` / `DayView` cleanup**: the pill grouping logic (regular / done / cancelled / habits rows), summary generation triggers, and section visibility conditions have been iterated heavily — audit for redundant conditionals, simplify padding logic, and consider whether any of it belongs in `DayViewModel` instead of the view
- **Bug: completed/canceled items still accept completion/cancellation gestures**: pills in the done or cancelled rows still have the swipe-left-to-cancel and swipe-right-to-defer gesture, and the context menu "Cancel Item" action. Fix: gate the `DragGesture` and context menu destructive action in `ItemPillView` on `item.status == .pending`.
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
- **Import from Things**: parse a Things export (markdown or JSON) and use Foundation Models to auto-assign each task to the appropriate day section, deadline, or recurring schedule
- Import from other sources (markdown like DayOne, etc.)

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
