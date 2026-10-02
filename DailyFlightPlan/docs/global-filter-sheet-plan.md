# Global Filter Button + Sheet — Design Plan

Design doc for Phase 2.5 (see `implementation-plan.md`). Written during planning on 2026-10-02;
not yet implemented — review before picking up.

## Context

Filtering today is scattered and inconsistent: `FlightPlanView` (Day tab) has a toolbar `Menu`
with five `@AppStorage` toggles plus a separate category button; `TimelineView` has its own
`safeAreaInset` filter bar with three different toggles (two of which don't exist anywhere else)
plus its own category capsule row plus a native `.searchable()` field with a duplicated filtering
code path; `RoutineView` has no filtering at all, not even category filtering.

This plan replaces all three per-view filter UIs with a single floating button (bottom-trailing,
above the tab bar, reachable from every tab) that opens one sheet. The sheet has a **General**
section (search text, category selection, flagged-only — things that already are or should be
meaningful on every tab) and a **Specific** section that adapts its contents to whichever tab is
currently active (Day gets show-completed/routines/calendar/reminders; Timeline gets
missed-only/completed-only; Routine gets nothing extra). Category management (add/rename/delete)
is reachable from the same sheet via the existing `CategoriesEditView`.

## Decisions locked in

1. Replaces FlightPlanView's toolbar filter menu + category button entirely — not additive.
2. Simple icon button (SF Symbol in a circular `.buttonStyle(.glass)` button), not a custom
   reproduction of the system search-tab chrome.
3. Timeline's filter bar is folded into the same sheet too (not left standalone) — but its
   Timeline-only concepts (missed-only, completed-only) become the "Specific" section when the
   Timeline tab is active, rather than being force-fit into general-purpose toggles.
4. Toggles that only make sense on one tab (show-routines, show-calendar-events,
   show-reminder-items, missed-only, completed-only) stay scoped to that tab's effect — the sheet
   itself displays a different Specific section per tab rather than showing all toggles everywhere.
5. Text search is in scope now: a General-section text field matching `PlanItem.title`/`.notes`,
   wired into Day, Timeline, and Routine's item lists.

Explicitly rejected: using SwiftUI's `Tab(role: .search)` for the button — that role is wired to
`.searchable()` text-field activation semantics, not arbitrary sheets, so it's the wrong tool for
a filter-sheet trigger even though it produces the visually-similar pinned trailing button.

## Current state (confirmed by exploration)

- `AppStorageKeys.swift` already has all the keys needed: `showFlaggedOnly`, `showCompleted`
  (Day's reveal-semantics), `showCompletedOnly`/`showMissedOnly` (Timeline's isolate-semantics,
  mutually exclusive), `showCalendarEvents`, `showReminderItems`, `showRecurring`,
  `selectedCategoryNames`. No new `AppStorageKeys` cases are needed.
- `CategorySelectionService` (`Services/Categories/CategorySelectionService.swift`) is already a
  shared `@Observable`/`UserDefaults`-backed service injected via
  `@Environment(\.categorySelectionService)`, with `filterItems(_:)`. Reuse as-is; just start
  calling it from `RoutineView` too (new behavior — Routine templates currently ignore category
  selection entirely).
- `PlanItem` has `title: String`, `notes: String` — the two fields search should match via
  `localizedStandardContains`.
- `FlightPlanView.activeItems(for:)` (~line 295) and `TimelineView.filteredItems`/`searchResults`
  (~lines 64–121) each independently implement overlapping filter predicates. Timeline's
  `searchResults` is a second, duplicated filtering code path for its native `.searchable()` field
  — this whole thing goes away and is replaced by the shared search-text filtering below.
- `DayView.swift` owns the `TabView` with `private enum AppTab { case focus, flightDeck, routines,
  timeline }` and already has `.sheet(...)` chains and a `.overlay { if isDeletingData { ... } }`
  directly on the `TabView` — the right attachment point for the new floating button, since it's
  outside all three tabs' content.

## File changes

### New: `Persistence/PlanItem+Filtering.swift`
Pure, stateless `Sequence where Element == PlanItem` extension, unit-testable with plain fixtures:
- `matchingSearchText(_:)` — `title`/`notes` `localizedStandardContains`, empty string = no-op.
- `matchingDayStatusFilters(showFlaggedOnly:showCompleted:showRecurring:)` — today's
  `FlightPlanView` predicate, extracted verbatim.
- `matchingTimelineStatusFilters(showFlaggedOnly:showCompletedOnly:showMissedOnly:isMissed:)` —
  today's `TimelineView` predicate, extracted verbatim (keep `isMissed(_:)` itself in
  `TimelineView` since it depends on `Date.now`/`Calendar`, pass it in as a closure).

### New: `Views/FilterSheetView.swift`
`NavigationStack` + `List`/`Form`, `.confirmationAction` "Done" button, mirrors
`CategoriesEditView`'s sheet skeleton:
- **General** section: `TextField` bound to a `searchText: Binding<String>`; horizontal
  `ScrollView` of `CategoryCapsule(category:)` over an injected `allCategories` + "Manage
  Categories" button (same as today's `categorySelectorSheet`, calls `onManageCategories()`);
  `Toggle` for `showFlaggedOnly`.
- **Specific** section, `switch` on an `activeTab` parameter passed in from `DayView`:
  - Day: toggles for `showCompleted`, `showRecurring`, `showCalendarEvents`, `showReminderItems`.
  - Timeline: toggles for `showCompletedOnly`/`showMissedOnly` (mutually-exclusive set logic
    moves here from `TimelineView.filterBar`).
  - Routine: no extra controls (section omitted).
- All toggles declared locally as `@AppStorage(AppStorageKeys.*.rawValue)` — same technique
  `FlightPlanView`/`TimelineView` already use, no new shared service needed for them.
- `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)`.

`DayView`'s private `AppTab` enum needs to stop being `private` (or a small mirror enum) so it can
be passed into `FilterSheetView` as the `activeTab` parameter.

### Modified: `Views/DayView.swift`
- De-privatize `AppTab` (drop `private`) so `FilterSheetView` can take it as a parameter.
- Add `@State private var isShowingFilterSheet = false`, `@State private var isShowingCategoriesEdit
  = false`, `@State private var searchText = ""` (ephemeral, not persisted — matches today's
  Timeline behavior).
- Add `@Query(sort: \PlanCategory.name) private var allCategories: [PlanCategory]` (not present
  today) to pass into `FilterSheetView` and `CategoriesEditView`.
- Add the five/seven relevant `@AppStorage` flags + `@Environment(\.categorySelectionService)`
  purely to compute an `isGlobalFilterActive` flag (combining General + whichever tab's Specific
  flags are active) for the button's filled/outline icon.
- New `.overlay(alignment: .bottomTrailing)` on the `TabView` (separate from the existing
  `isDeletingData` overlay, which is centered and `.ignoresSafeArea()`): circular ~52×52pt button,
  SF Symbol `line.3.horizontal.decrease.circle`/`.fill`, `.buttonStyle(.glass)`, trailing/bottom
  padding for FAB-style spacing. Not ignoring the safe area means it naturally sits just above the
  system tab bar without manual height math.
- `.sheet(isPresented: $isShowingFilterSheet)` presenting `FilterSheetView(allCategories:,
  searchText: $searchText, activeTab: activeTab, onManageCategories: { ... })`, chaining to
  `.sheet(isPresented: $isShowingCategoriesEdit) { CategoriesEditView(allCategories: allCategories)
  }` the same deferred-dismiss-then-present way `RoutineView` already chains two sheets.
- Thread `searchText` down into each tab's view (`FlightPlanView(..., searchText: searchText)`,
  `TimelineView(..., searchText: searchText)`, `RoutineView(searchText: searchText)`).

### Modified: `Views/FlightPlanView.swift`
- Remove the filter `Menu` and category `tag` button from `ToolbarItemGroup` (theme menu and `+`
  add button stay).
- Remove `showCategorySelector`/`categorySelectorSheet`/`isShowingCategoriesEdit` and their
  `.sheet` modifiers (category management now lives behind `DayView`'s sheet chain).
- Accept new `searchText: String` init parameter.
- `activeItems(for:)` becomes: date match → `.matchingDayStatusFilters(...)` →
  `.matchingSearchText(searchText)` → `categorySelectionService?.filterItems(...)`.
- Keep `@AppStorage` flag declarations, `@Environment(\.categorySelectionService)`, and the
  `isFilterActive`-derived gating of calendar/reminder inline display (~lines 206–209, 330–334) —
  that logic is independent of the toolbar UI being removed and must survive verbatim.
- Remove `@Query private var allCategories` if nothing else in the file still uses it after the
  sheet/button removal (grep before deleting).

### Modified: `Views/TimelineView.swift`
- Remove `filterBar` and its `.safeAreaInset(edge: .top)` attachment, and the `.searchable(text:)`
  modifier + duplicated `searchResults` computed property.
- Accept new `searchText: String` init parameter (replaces the old local `@State searchText`).
- Collapse `filteredItems` to use the new shared extension: date/load-window check (unchanged,
  view-specific) → `.matchingTimelineStatusFilters(...)` → `.matchingSearchText(searchText)` →
  `categorySelectionService?.filterItems(...)`. This also removes the pre-existing duplication
  between `filteredItems` and `searchResults`.
- Keep `isMissed(_:)` as-is; keep the `@AppStorage` flag declarations (still read here for
  filtering; just no longer have their own toggle UI in this file).

### Modified: `Views/RoutineView.swift`
- Accept new `searchText: String` init parameter and `@Environment(\.categorySelectionService)`.
- Apply `.matchingSearchText(searchText)` and `categorySelectionService?.filterItems(...)` to
  `templates` before grouping/display. This is new behavior (Routine currently has zero filtering)
  but follows directly from promoting search + category to "General, applies everywhere."

### `AppStorageKeys.swift` / `Environment.swift` / `CategorySelectionService.swift`
No changes needed — confirmed all required keys and the shared service already exist.

## Testing

- New `PlanItem+FilteringTests.swift` (Swift Testing, mirrors `PlanItemTests.swift`/
  `DaySectionTests.swift` style): parameterized `@Test(arguments:)` cases over
  `matchingSearchText`, `matchingDayStatusFilters`, and `matchingTimelineStatusFilters` using plain
  `PlanItem` fixtures (no SwiftData container needed) — covers flagged/unflagged ×
  completed/canceled/pending × recurring/non-recurring × search-match/no-match combinations.
- Manual/UI verification (via `RunProject`/simulator):
  - Floating button sits correctly above the tab bar on all three tabs, doesn't overlap the tab
    bar or system chrome.
  - Sheet's Specific section correctly swaps content when switching tabs before reopening the
    sheet.
  - Toggling each control updates the corresponding tab's item list identically to today's
    pre-removal behavior (regression check, since old toolbar/filter-bar UI is deleted, not just
    moved).
  - Search text filters Day/Timeline/Routine item lists by title and notes.
  - Chained sheet dismiss → `CategoriesEditView` present timing looks clean (no flash/jump).
  - `BuildProject` to confirm compiles; `RunAllTests` for the new filtering unit tests.

## Follow-up (once implemented)
Mark Phase 2.5 ✅ in `implementation-plan.md` with a note on the General/Specific sheet design and
the Routine-now-respects-category/search deviation from the original placeholder notes.
