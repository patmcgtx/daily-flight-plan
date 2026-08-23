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
- Calendar selection UI deferred to Phase 21 (Settings); all calendars shown by default

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
- **Deferred**: reminder list selection UI — moved to Phase 21 (Settings)

### ✅ Phase 9 — Workflow Refinements
- **Spillover**: On app launch (and at midnight if the app is open), pending items from any date before today are moved to today. Deadline-based items have their deadline cleared and become "any time" items (already flagged as missed). Recurring items spill as-is (no duplicate created for the new day). Navigation moves to today after spill.
- **"Past" section**: When viewing today, sections whose time window has already ended are hidden from the main section list. Their past calendar events appear in a non-section "Past" area at the top of the scroll view. Pending plan items from those sections appear in the "Any Time" area via the missed-item logic. Timed reminders from past sections appear in the "Missed" area.
- **"Missed" section**: Dedicated non-section area (above "Any Time") for pending items whose specific deadline has passed and for past timed reminders. Uses `DeadlineItemRow` to show the missed time.
- **"Any Time" split**: Untimed items and section-based items whose section has ended (but had no specific deadline) appear in "Any Time". Deadline-missed items moved to "Missed".
- **Live clock**: A per-minute timer drives `currentSection` and `activeSections` so the Past/Missed areas grow in real time as sections end during the day.
- **Projected recurring items**: On future dates, recurring section-based habits that apply to that weekday appear as ghosted (35% opacity, non-interactive) pills in their section — a preview of the expected day, not yet committed items.
- **Richer seed data**: Recurring habits across all five sections plus timed and untimed items for thorough testing.
- **Deferred**: Drag to reorder items between sections → Phase 10

### ✅ Phase 10 — UI Refinements
- **Drag to reassign section**: Long-press any section pill or deadline row to drag it to a different day section card. Dropping onto a section sets `item.daySection` and clears any deadline. Dragging to "Open" clears both (`daySection = nil`, `deadline = nil`). Each section highlights with an accent-colored border while a drag is over it. Added `uuid: UUID` to `PlanItem` as a stable drag token. "Open" also acts as a drop target, with an empty placeholder shown when it has no items.
- **Calendar / Reminders toggles**: Filter-bar `Calendar` and `Reminders` toggle pills added to the filter row (stored in `@AppStorage` as `showCalendarEvents` / `showReminderItems`, both on by default). When toggled off, events/reminders are hidden from all sections, Past, Missed, and Open.
- Renamed "Any Time" → "Open" (works for today and all other dates)
- Remaining visual refinements (Calendar/Reminders row treatment, recurring item layout) moved to Phase 17 (Brand New Focus View)

### ✅ Phase 11 — Timeline View
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
- **Deferred**: lazy-load past + future days — moved to Phase 16 (Finish Timeline View)

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

### ✅ Phase 13 — Nav & Chrome Rework (Liquid Glass)
- **Retire swipe gestures**: replaced swipe-left-to-cancel and swipe-right-to-defer with long-press context menu only (cancel/defer drag zones also removed)
- **Remove sticky header**: entire top header (date row + filter row) removed; no more material bar at the top
- **Date label scrolls with content**: weekday + month/day + prev/next chevrons are now the first item in the scroll view's LazyVStack; they scroll along with the sections
- **System TabView** (Focus · Timeline · Search) replaces the custom bottom bar; tab bar gets Liquid Glass automatically on iOS 26; `Tab(role: .search)` pins Search to trailing edge
- **Add button in toolbar**: `[+]` is a `ToolbarItem(placement: .topBarTrailing)` on the Focus tab, sitting outside the filter group so it gets its own glass capsule
- **Toolbar controls on Focus tab**: `NavigationStack` with `ToolbarItemGroup(placement: .topBarTrailing)` — filter menu · categories · theme — grouped by the system into a single Liquid Glass cluster; settings alone on `.topBarLeading`
- **Active state on filter & theme buttons**: filter uses `.fill` icon + accent color when `showFlaggedOnly || showCompleted`; theme uses `.fill` paintbrush + accent color when not `.cupertino`
- **Filter icon**: `line.3.horizontal.decrease.circle` (standard iOS filter icon, not sliders)

### ✅ Phase 14 — Usability Part 2
- Use the app daily for a real period of time — real tasks, real calendar events, real reminders
- Note friction points, readability issues, missing features, visual rough edges, and anything that feels off in actual use
- Gather a prioritized list of changes needed before shipping version 1.0
- **"All clear" for completed sections**: when a collapsed section has no remaining pending items (all done/cancelled or nothing), display "All clear" in the header instead of an AI summary — a small reward for finishing the section
- **Consistent indentation of items in a day section**: regular pending pills now use `labeledPillRow(icon: "list.dash", ...)` so they align with the done (✓), canceled (✗), and habits (∞) rows — all four pill groups share the same icon-column layout
- **Import Reminder as PlanItem**: long-press a `ReminderItemRow` to get a context menu with "Import as Task"; creates a `PlanItem` from the reminder's title, notes, and dueDate (stored as a `deadline`, placing it in the right section automatically); stores `reminderIdentifier` for future two-way sync; the original reminder is left unchanged
- **Rename day "section" to "segment"**: more in line with the flight/airplane analogy; user-facing terminology only for now
- **Animation while waiting for section summary**: while a section summary is being generated by local AI, show a "..." animation
- **Section summary reload option**: a small reload icon after an AI-generated section summary lets the user generate a fresh summary
- **AI summary quality**: all timed items (deadline plan items, calendar events, and timed reminders) are merged and sorted by clock time and appear first; followed by non-recurring one-off tasks, untimed reminders, and recurring habits — so the most time-sensitive items always surface first in the summary

### ✅ Phase 15 — Fix Recurring Items / Habits / Routine Behavior
- Implemented a **template + per-day instance model** using a self-referential `@Relationship` on `PlanItem`:
  - `isTemplate: Bool` — true for recurring habit templates
  - `template: PlanItem?` — links each per-day instance back to its template
  - `instances: [PlanItem]` — inverse relationship; populated only on templates
  - `isRecurring: Bool` — computed: `isTemplate || template != nil`
- **Materialization**: per-day instances are created lazily when `DayView` loads a date (`materializeRecurringInstances(for:)`); only missing instances are created, so it's idempotent
- **Migration**: `migrateOldRecurringItems()` detects old-style recurring items (non-template with `recurringWeekdays` set) and converts them to templates on first load
- **`@Query` split**: `allItems` now excludes templates (instances + one-off items only); `recurringTemplates` fetches templates only — this ensures templates are never shown as regular day items
- **Spillover skips instances**: recurring instances are not spilled to the next day (each day gets a fresh instance via materialization)
- **`ItemForm` template-aware**: hides the recurring schedule picker when editing an instance; nav title reads "Edit Routine" for templates vs. "Edit Item" for instances
- **`ItemFormViewModel`**: saves recurring schedule and `isTemplate` only on templates/one-offs; instances inherit schedule from their template
- **Sheets trigger re-materialization on dismiss**: so newly created templates get instances for the current day immediately
- **Materialization is today-only**: future dates never get instances created — they show read-only ghost projections instead; past dates retain their historical instances
- **Defer hidden for recurring instances**: "Defer to Tomorrow" is only offered for one-off items; recurring instances can only be completed or canceled, since tomorrow's habit appears automatically
- Self-referential `@Relationship` (not UUID) used for CloudKit compatibility

### ✅ Phase 16 — Multi-View UX Experiment
- Added two alternative views alongside the Cockpit (day view):
  - **Cards view** (`CardDeckView`) — vertically stacked section cards; collapsible headers with AI summary (or loading dots / count fallback) in collapsed state, full progress ring + item list when expanded; current section expanded by default on today; date navigation header; full filter/category/theme toolbar; `+ Add item` inside content area
  - **Nav Log** (`TimelineView` renamed) — chronological multi-day list; items fully interactive (checkbox completes, tap opens edit form, long-press for Edit/Cancel context menu); Flagged/Done filter bar with category capsules
- **Tab renames**: "Focus" → "Cockpit" (`airplane` icon); "Timeline" → "Nav Log" (`book.pages` icon); "Cards" tab added (`rectangle.stack` icon)
- **Grid view built and dropped**: iterated on a 2-column grid overview with AI summary tiles; removed after review — three views is the right number
- All three views (Cockpit, Cards, Nav Log) are live for extended usability testing before deciding what stays in 1.0

### ✅ Phase 17 — iCloud Sync
*Moved up from Version 2.0 — planning on Mac and executing on iPhone is the core workflow.*
- Added `iCloud.com.patmcg.DailyFlightPlan` to `com.apple.developer.icloud-container-identifiers` in entitlements (Background Modes + remote-notification were already in `Info.plist`)
- Updated `ModelContainers.persistentContainer()` to use `cloudKitDatabase: .private("iCloud.com.patmcg.DailyFlightPlan")`
- Removed `@Attribute(.unique)` from `PlanCategory.name` — CloudKit cannot enforce uniqueness constraints; uniqueness is already enforced in `CategoriesEditViewModel` in code
- **`SelectedCategories` removed from SwiftData**: CloudKit requires all relationships to have inverses; `SelectedCategories.categories` had no inverse on `PlanCategory`. Migrated to `UserDefaults`-backed `CategorySelectionService` (device-local filter state intentionally not synced)
  - `AppStorageKeys.selectedCategoryNames` added for the new storage key
  - `CategorySelectionService` rewritten as a plain `@Observable` class using `UserDefaults`; no longer needs `ModelContext`
  - `SelectedCategories.swift` deleted from the project
  - `InjectLiveServicesModifier` / `InjectMockServicesModifier` updated to use `@State private var categoryService = CategorySelectionService()` (stable across re-renders; no `modelContext` dependency)
- Self-referential `@Relationship` on `PlanItem` (template ↔ instances) verified compatible: both sides have explicit inverses, `.nullify` delete rule, and optional to-one side — all CloudKit requirements met
- **Note**: CloudKit schema must be initialized in the CloudKit Console before first production release; use the DEBUG schema initialization flow from Apple docs if needed before shipping

### ✅ Phase 18 — Mac Support
*Moved up from Version 2.0 — needed alongside iCloud sync for the plan-on-Mac, execute-on-iPhone workflow.*
- Project already had `TARGETED_DEVICE_FAMILY = "1,2,7"`, `SUPPORTED_PLATFORMS` including `macosx`, and `MACOSX_DEPLOYMENT_TARGET = 26.5` — no project file changes needed
- Created `Common/ViewExtensions.swift` with platform-conditional View + `ToolbarItemPlacement` extensions:
  - `inlineNavigationTitle()` — no-op on macOS (`.navigationBarTitleDisplayMode(.inline)` is iOS-only)
  - `.trailingBar` / `.leadingBar` — resolves to `.automatic` on macOS (`.topBarTrailing` / `.topBarLeading` are iOS-only)
- Applied `inlineNavigationTitle()` across `DayView`, `CardDeckView`, `TimelineView`, `ItemForm`, `CategoriesEditView`
- Applied `.trailingBar` / `.leadingBar` in `DayView` and `CardDeckView` toolbar items
- Fixed `.listStyle(.insetGrouped)` → `#if os(macOS) .inset #else .insetGrouped #endif` in `TimelineView`
- **Deferred**: keyboard shortcuts, menu bar integration, window minimum size, VoiceOver testing — deferred until post-iCloud sync when the Mac workflow can be exercised end-to-end


### ✅ Phase 19 — UX and Usability Sprint
Mac and iCloud sync usability testing, plus day-view UX experiments and aviation-themed polish.

- **Mac Calendar/Reminders fix**: Added `com.apple.security.personal-information.calendars` and `com.apple.security.personal-information.reminders-data` sandbox entitlements to the macOS app — EventKit access was silently blocked without them
- **ItemForm scrollable on macOS**: Categories section wrapped in a `ScrollView` with `maxHeight: 200` so the form fits on screen regardless of category count
- **Flight Plan view** (`FlightDeckView.swift`, struct `FlightPlanView`) — new primary day view replacing the Cockpit tab:
  - Left/right swipe between days: `TabView(.page)` infinite-reset pattern on iOS (3 pages: yesterday/today/tomorrow; snap back to center page silently after each swipe); `DragGesture` fallback on macOS
  - Card-based layout: one collapsible `RoundedRectangle(cornerRadius: 18)` card per day section, matching `CardDeckView` style
  - "Today" label in the date header when viewing today (accent colored); `scope` go-to-today button appears on non-today dates at the leading edge
  - Section cards: collapsed (header only, with count and AI summary text) / expanded (full item list, `+ Add item` link); full-area tap target on the entire header
  - Progress ring per section: always shows raw `completed/total` plan-item counts, unaffected by filters; green when all done
  - `HFlow` for non-deadline items (pills); `DeadlineItemRow`-style rows for timed items
  - Filter-driven expand/collapse: when a filter is active, sections with matching items auto-expand; sections with no matches collapse; user can still manually override afterward
  - Calendar events and Reminders: shown in expanded section cards (`CalendarEventRow`, `ReminderItemRow`) and in the Open card; passed from `DayView` (which already fetches them); only shown for the currently-selected date (side swipe pages get plan items only)
  - Drag-and-drop between sections: pills are `.draggable`; each section card and the Open card are `.dropDestination`; drop target highlights with accent border
  - Filter menu includes Calendar Events and Reminders toggles (with Divider before them)
- **Tab restructure**: Cockpit and Cards tabs commented out; four active tabs:
  - **Day** (`airplane`) — Flight Plan view (primary day view)
  - **Log** (`checklist`) — Nav Log / Timeline
  - **Routine** (`infinity`) — `ContentUnavailableView` placeholder for future routine editing
  - **Comm** (`apple.intelligence`) — `ContentUnavailableView` placeholder for future AI chat
- **macOS keyboard shortcuts**: `Cmd+1`–`Cmd+4` switch between the four active tabs; implemented as hidden zero-size `opacity(0)` buttons in an `.overlay` (`.hidden()` would disable keyboard shortcut dispatch)
- **Routine items row**: in expanded section cards, recurring (routine) pills are separated from regular pills onto their own `HFlow` row with a single `∞` icon at the leading edge; per-pill infinity badge suppressed (`showRecurringBadge: false`); regular pills get a matching `calendar.day.timeline.left` icon for visual symmetry
- **Notes indicator on pills**: `ItemPillView` shows a `note.text` icon (`.tertiary`) after the title when `item.notes` is non-empty — a subtle at-a-glance signal that notes exist
- **Progress row in Flight Plan view**: `progressRow(for:)` shows a `ProgressRingView` + completion text ("All done!" / "N of M complete" / "No items planned") at the bottom of each day's scroll content
- **Overdue section badge**: when viewing today and a section's time window has passed with pending items remaining, the header count shows `! N/M` in orange; all-done sections show `✓ N/N` in green
- **Reminders deep link**: tapping a `ReminderItemRow` opens the Reminders app via `x-apple-reminderkit://` URL; an `arrow.up.right.square` icon at the trailing edge signals the deep link; "Open in Reminders" also in the context menu

### ✅ Phase 20 — Routine View
- `RoutineView.swift` — recurring habit template management
- Items grouped by weekday pattern (Every Day / Weekdays / Weekends / custom); each pattern is a card
- Within each card, items are subdivided by day segment; timed items get a full-width deadline row, untimed items flow as `HFlow` pills
- Tap any pill/row → opens `ItemForm(item:)` to edit the template; long-press → Edit / Delete context menu
- Drag pills between cards to reassign their weekday pattern
- `+` button in toolbar and per-card add button → `ItemForm` pre-wired for that weekday pattern
- Custom weekday sections: `+` in toolbar opens a weekday-circle picker; delete with confirmation (severs templates from historical instances, which become standalone records)
- Empty card state shows "No routines yet." inline
- Wires into the existing `Routine` tab (`AppTab.routines`) in `DayView`
- **Visual refinements (post-initial):** card backgrounds match FlightPlanView (`.background` fill, 0.5pt border, subtle shadow); headers use `.title2.bold()` font and `accentColor.opacity(0.04)` tint; tap header to expand/collapse each card (all start expanded; collapsed state shows name + item count in `.headline` + `.caption`)

### ✅ Phase 21 — Markdown Import
Paste markdown or plain text (e.g. a Things export) → Foundation Models parses it → modal review list → save or cancel.

- **Entry point**: `arrow.down.doc` button in the Flight Plan toolbar (leading bar, next to the gear)
- **Two-step sheet** (`MarkdownImportView`):
  1. **Paste step**: `TextEditor` pre-populated from the clipboard; "Parse" button triggers the AI parse
  2. **Review step**: list of proposed items with section chip and recurring badge; swipe-to-delete; "Add N" commits and dismisses; "← Back to text" returns to step 1
- **Foundation Models structured generation**: `@Generable ParsedTask` (title, section, isRecurring, schedule) wrapped in `@Generable ParsedTaskList`; `LanguageModelSession` with task-extraction instructions; graceful fallback (regex strip) when `SystemLanguageModel.default.isAvailable` is false
- **Date handling**: all imported items land on `viewModel.selectedDate` regardless of any date string in the input (e.g. "08/22/2026" is stripped, not parsed as the item's date)
- **Recurring items**: items marked recurring by the model are saved as templates with `isTemplate: true`; non-recurring items saved as one-off `PlanItem`s; weekday schedule parsed from "everyday" / "weekdays" / "weekends" / comma-separated abbreviations (mon, tue…)
- **Section mapping**: AI outputs one of firstThing / morning / midday / afternoon / evening / bedtime / open; "open" (or unknown) → `daySection = nil` (any time)
- Wired into `DayView` via `onShowImport` callback on `FlightPlanView`; sheet dismissal triggers `materializeRecurringInstances` so any new templates immediately appear as today's instances

### ✅ Phase 22 — Chat / Quick Entry (Natural Language)
Implemented as a focused Q&A chat on the Comm tab (quick item entry deferred — see Phase 22b below).

- **`CommView`** (`CommViewModel`) replaces the placeholder on the Comm tab
- **Context injection**: today's and tomorrow's plan items (with section, status, deadline) are serialized into the `LanguageModelSession` system prompt on tab appear; "ghost" recurring habits from templates are included in tomorrow's context
- **Streaming responses**: `streamResponse(to:)` → `for try await snapshot in stream` — response text streams live into the bubble as it generates
- **Typing indicator**: three animated dots while awaiting the first token
- **New conversation** button (`plus.bubble`) rebuilds the session with fresh context and clears history
- **Unavailability**: `ContentUnavailableView` shown when `SystemLanguageModel.default.isAvailable` is false
- **Deferred**: quick item creation via natural language (originally part of Phase 22) — see Phase 22b

- Consider adding a local AI-based chat mode *on its own new tab*, where you can use natural language to do whatever:
  - Quick-enter new items — e.g. "Call dentist tomorrow at 2pm", "Run every weekday morning", "Buy milk — flagged"
  - Ask questions about your day
- Replace (or augment) the "Add Item" button with a free-text entry field?
- Possible paid upgrade eventually — make sure the quality is good first!
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

### Phase 23 — Finish Nav Log
- The Nav Log should show *all* days, past, present, and future — a time machine of sorts
- Past days show a history of what was completed (and canceled)
- Future days show scheduled items and projected recurring items, which are non-interactive
- Allow the usual editing on today and future planned items, with swipe gestures for cancel, defer, flag, and delete
- A share icon for each day — can be a basic first pass or even a visual placeholder for now
- **Search**: `.searchable` modifier on the Nav Log list; filters by title and notes across all dates; results appear inline replacing the normal date-grouped list; tap a result to navigate to that day
- Implementation notes:
  - **Lazy-load past days**: start with today and load past days on demand as the user scrolls, rather than fetching all history at once
  - **Lazy-load future days**: start with today and load future days on demand as the user scrolls; future days show recurring items and items scheduled for that day

### Phase 24 — Finish Day/Flight View
> **Partially addressed by Phase 19 (Flight Plan view).** The swipe pager, card layout, Calendar/Reminders integration, and drag-and-drop are done. Remaining items below.
- Based on what we've learned so far, let's create a brand new, cleaner focus view
- **Progress indicator**: rework this — it needs to be *in* the day view somewhere; possibly go horizontal
- **Visual treatment of Calendar events and Reminders**: make them stand out more (or less) from plan items — for example, italic font or a distinct row style
- **Visual treatment of recurring items / habits**: make habits stand out in a more intuitive way; the infinity icon approach works — consider a different layout altogether
- Possibly more of an "accordion" view like iOS lock screen notifications ("show less" / "show more"), instead of a traditional expand/collapse view
- Remember: the goal of this view is to focus on what's important right now but have access to the rest of the day, as if you're flying an airplane!
- **Start** with a view that can be cleanly swiped left and right for yesterday/tomorrow — see Phase 27 (Smooth Day Swipe Navigation Pager)
- Refactor services and view models as we go — we want this stuff pristine and unit-testable
- Add unit tests once happy with the behavior
- Can we reuse the existing view models?

### Phase 25 — Settings
- `SettingsView` navigated to from ⚙ button
- **Calendar settings**: toggle to enable/disable calendar event display; multi-select list of available calendars (uses `CalendarService.availableCalendars()` + `AppStorageKeys.selectedCalendarIDs`; empty = all); if permission was denied or not yet granted, show a link to open Settings
- **Reminders settings**: similar toggle + list picker for reminder lists; same permission recovery link
- **Permission prompt on first filter tap**: when the user taps the Calendar or Reminders filter pill for the first time, prompt for permission then and there (rather than waiting for the day to load); on grant, show the calendar/list selector immediately
- **Day section boundaries**: edit start/end hours for each day section; store in `@AppStorage`; `DaySection.containing(_:)` reads from stored values instead of hardcoded hours; also update `DaySection.timeRangeLabel` to compute dynamically from stored boundaries instead of hardcoded strings
- **"Rise & Shine" pre-morning section**: consider adding an early-morning section (e.g. 5–6 AM) for first-thing-out-of-bed habits; or expose Morning's start time as a user-adjustable boundary so the section stretches to cover it
- **Rename "Night" → "Bedtime"**: or make section names user-editable alongside their time boundaries
- Any other preferences surfaced here as phases are completed

### Phase 26 — Local Notifications
- Request notification permission on first use of a deadline item
- Schedule a `UNUserNotificationCenter` notification when a deadline item is saved
- Cancel/reschedule notifications when item is edited, completed, canceled, or deferred
- Notification times respect custom day section boundaries from Phase 25 (Settings)

### ✅ Phase 27 — Smooth Day Swipe Navigation (Pager)
- Implemented as part of Phase 19 (Flight Plan view): 3-page `TabView(.tabViewStyle(.page))` infinite-reset pattern on iOS, `DragGesture` fallback on macOS; left/right swipe navigates between yesterday, today, and tomorrow

### Phase 28 — Fit and Finish
- Address findings from Phase 14 usability testing
- Bug fixes, UX tweaks, visual polish
- **Aviation-themed day-view additions**: Add a place to give the day a "name" (like "Aircraft Identification" in a real flight plan; default to YYYYMMDD); explore "Flight Rules" and "Type of Flight" (work day / weekend / vacation?) fields; a "Today's Destination" field with placeholder "What are your goals for today?" — an open-ended text field for the day's purpose
- **Day note area**: a freeform text field at the top of the day view for "what is today all about?" — a one-line intention or focus for the day; persisted per-date
- Get a nice AI summary of the day once it's complete, in the day view, as a sort of reward
- Are we hiding day segments that have passed?
- **Readability & accessibility**: Dynamic Type support across all text styles; VoiceOver labels on interactive elements (pills, rows, filter toggles, progress ring); minimum tap target sizes; sufficient color contrast in all themes; test with Accessibility Inspector. **Immediate concern: font sizes and contrast are too small/dim — prioritize this.**
- **Missed item rule to consider**: when a day section has passed and items are left in it, move everything to "Open"
- **Summary vs. full view** *(defer until Phase 22 Chat/Quick Entry is done — both touch the collapsed section UI and Foundation Models)*: reconsider the collapsed/expanded section toggle as a "summary vs. full" mode — the collapsed state could show a compact AI-generated summary card, and the expanded state shows the full item list; more flight-plan-like than a simple show/hide
- **Make Calendar and Reminders access read-only**: no need for read/write access anymore
- **Haptics**: `UIImpactFeedbackGenerator` on complete, cancel, and defer actions; `UINotificationFeedbackGenerator` on completion celebration
- **High contrast theme**: new `DFPTheme` case with larger text, stronger borders, and high-contrast color pairs
- **Completion celebration**: when the last pending item is checked off for the day, trigger a reward moment — confetti burst or similar animation, progress ring transforms into a large checkmark (or full green fill), brief haptic feedback
- **Aviation UI spike**: explore a "flight plan" visual style — monospace/typewriter fonts, cockpit-dark palette, section headers styled like flight log rows, checklist-style rendering. Could be a new `DFPTheme` case or a separate `UIStyle` dimension. Prototype freely; keep what feels right, discard the rest. Findings feed into Version 3.0 planning.
- **Localization**: wrap all user-visible strings in `String(localized:)` or `LocalizedStringKey`; add a base `Localizable.xcstrings` catalog; verify date/time formatting uses locale-aware formatters (already done via `.dateTime` format style)
- **iCloud sync status indicator**: surface iCloud sync state to the user — detect whether iCloud is signed in and whether the CloudKit container is reachable; show a subtle banner or Settings badge if sync is unavailable (signed out, iCloud Drive disabled, or network unreachable); explain what it means for cross-device data (not lost, just not synced yet); deep-link to Settings for remediation
- **iCloud sync error handling**: handle and surface CloudKit error conditions gracefully — out-of-storage (prompt to manage iCloud storage), network offline (silent retry with status indicator), container initialization failure (fallback to local-only mode with a clear explanation); avoid silent data loss or confusing missing-item states
- **Startup freeze**: app visibly freezes for a moment on cold launch before becoming interactive; profile with Instruments (Time Profiler + SwiftUI) to find the bottleneck — likely candidates are SwiftData store initialization, initial `@Query` evaluation, or first-run spillover/materialization happening on the main thread
- **Calendar/Reminders load delay on day switch**: noticeable lag when navigating to a new day because `fetchCalendarEvents()` and `fetchReminderItems()` are triggered by `.task(id: viewModel.selectedDate)` and run sequentially; consider prefetching adjacent days, caching results, or showing a subtle loading state while data arrives
- **Clean up seed data**: personal test habits in `ModelContainers.swift` must be removed or replaced with a minimal, generic example set before shipping
- **Per-section add button**: consider a small `+` button on each section header (or in the section content area) so the user can add an item directly into that section without going through the main Add form and re-selecting the section
- **Relocate "+" button to thumb zone**: move Add Item out of the top navigation bar and into the lower portion of the screen (within thumb reach), similar to the floating compose button in Mail and the new-reminder button in Reminders; explore options that don't conflict with the system tab bar
- Add an app icon

### Phase 29 — Tech Debt
- Drop old Focus/Cards view code once no longer needed (CardDeckView, commented-out Cockpit tab, etc.)
- Audit and fix architectural issues — too much logic in views that belongs in view models, or view model logic that belongs in services
- Check and clean up file and class organization; update the architecture doc
- Architecture review & refactor
- **Rename day "section" to "segment"**: make this change in the code as well
- **Shared component library with MapsPlus** *(tech note)*: `DFPTheme`/`DFPThemeViewModifier`, `CategoryCapsule`, `CategorySelectionService`/`SelectedCategories`, `CategoriesEditView`, and `AppStorageKeys` are near-identical to their MapsPlus counterparts. When the time is right, extract these into a local Swift Package (e.g. `AppSharedUI`) shared by both targets. Candidate modules: `Theming` (theme enum + modifier), `CategorySelection` (service + views), `CommonPreferences` (AppStorageKeys pattern). Do NOT do this until both apps are stable — premature extraction adds friction with no user benefit.
- **`DaySectionView` / `DayView` cleanup**: the pill grouping logic (regular / done / cancelled / habits rows), summary generation triggers, and section visibility conditions have been iterated heavily — audit for redundant conditionals, simplify padding logic, and consider whether any of it belongs in `DayViewModel` instead of the view
- **Bug: completed/canceled items still accept context menu actions**: pills in the done or cancelled rows still show the "Cancel Item" context menu action. Fix: gate the context menu destructive action in `ItemPillView` on `item.status == .pending`.
- **✅ CloudKit dedup for user-created templates**: `deduplicateItems` now performs a second pass matching `title + daySection + recurringWeekdays`, merging instances onto the canonical copy before deleting duplicates.
- Unit tests (Swift Testing framework): `DayViewModel`, `ItemFormViewModel`, `CategoriesEditViewModel`, `CategorySelectionService`, `DaySection`, `CalendarService`, `RemindersService`
- UI tests (XCUIAutomation): core flows — add item, complete item, cancel/defer item, navigate days, open settings

### Phase 30 — Beta Testing
- Get this in other people's hands for initial impressions, questions, bugs, and—do they find it useful?
- We'll want to get them to test In-App Purchase, etc. too.

#### CloudKit initialization
CloudKit needs its schema initialized once. Steps:

Run a DEBUG build (once the entitlement above is fixed) on a device signed into a real iCloud account — this creates the record types/fields in the Development environment of the CloudKit dashboard automatically, inferred from your SwiftData models.
Check CloudKit Console → your container → Schema, confirm CD_PlanItem/CD_PlanCategory (or similar) record types appear under Development.
Before you ship to the App Store, use Console's Deploy Schema Changes to Production — Production schema doesn't auto-update from a release build, so skipping this step means TestFlight/App Store users get failures.

---

## Version 2.0

### In-App Purchases
- **Monetization model TBD** — likely a free tier with limits + optional unlock
- **Pricing model:** three individual unlocks at $0.99 each, bundled as "Daily Flight Plan Pro" at $1.99
- **Individual unlocks (TBD — need a 3rd):**
  - **Pro Themes** ($0.99) — unlocks 8-Bit, Kerby, Flamingo, and any future themes; Standard/Cupertino always free
  - **Unlimited Categories** ($0.99) — free tier capped at 5 categories; this removes the cap
  - **[Third unlock TBD]** ($0.99) — candidates: Quick Entry (natural language), Timeline history beyond 30 days, advanced recurring rules, custom section names/times
- **Daily Flight Plan Pro bundle** ($1.99) — all three unlocks; $0.98 savings vs. buying separately
- **StoreKit 2** for purchase flow (`Product`, `Transaction`, `EntitlementManager` pattern)
- Gate category creation in `CategoriesEditViewModel`: count existing categories, show upsell sheet if at limit and no entitlement
- Gate theme picker in the theme menu: dim/lock unpurchased themes, show purchase prompt on tap
- `EntitlementManager` service (protocol + live StoreKit + mock) injected via `@Environment` — same pattern as `CalendarService` and `RemindersService`
- Restore purchases flow (required for App Store)

### Rich Item Content
- **Web links**: add an optional `url: URL?` field to `PlanItem`; surface in `ItemForm` as a "Link" row (paste or type a URL); display as a tappable row in the day view and nav log (opens in-app browser via `SFSafariViewController` or system browser); show a globe icon on pills/rows that have a link; include URL in any export/share output
- **Photos**: add photo attachments to items — store images externally (CloudKit `CKAsset` or a local file URL referenced from the model, not raw data in SwiftData) to avoid hitting SwiftData/CloudKit record size limits; allow one or more photos per item; show a thumbnail strip in the edit form and a compact camera icon badge on pills; photo viewer on tap; full iCloud sync of assets; consider storage implications and warn the user if iCloud storage is low

### iPad Support
- Adopt adaptive layout using `horizontalSizeClass` — on regular width, consider a two-column split (e.g. date/section list on left, day detail on right)
- Verify `HFlow` pill layouts scale well on wider screens
- Keyboard navigation and hardware keyboard shortcuts (arrow keys to navigate days, etc.)
- Test with Stage Manager and multitasking split views
- Pointer/cursor hover states for trackpad users

---

## Version 3.0

### Siri & AI
- Support Siri for adding items and asking specific questions
- Opt into iOS AI support so Siri can know about my daily plan

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
