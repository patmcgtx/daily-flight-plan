# Port MapsPlus's Category Selector UX into DailyFlightPlan (interim implementation)

Sub-plan of Phase 2.5 (see `../implementation-plan.md` and `global-filter-sheet-plan.md`). Written
during planning on 2026-10-02.

**✅ Implemented 2026-10-03.** At the time, `.popover(...)` + `.presentationCompactAdaptation(
.popover)` was believed to be broken on this project's iOS 27 beta (rendered full-screen, no
dismiss) and was dropped in favor of a `.presentationDetents` sheet fallback on iPhone. **Corrected
2026-10-05**: that belief was wrong — the real gap was a missing explicit `attachmentAnchor`/
`arrowEdge` and content `.frame(minWidth:idealWidth:maxWidth:)`, confirmed by comparing against
MapsPlus's working popover. This standalone category popover was itself removed/superseded in
Phase 2.5 (category selection now lives inside `FilterSheetView`, opened via `.popover(...)` +
`.presentationCompactAdaptation(.popover)` with correct sizing) — see `global-filter-sheet-plan.md`
and `docs/known-bugs.md`'s Fixed section for the full writeup. Floating "+" buttons on
FlightPlanView/RoutineView (also decided alongside this plan) were implemented in the same pass —
see `global-filter-sheet-plan.md`'s "Add button" section.

## Context

The user wants the category selector + editor UX from their MapsPlus app (a "Categories" card
with Clear/Edit buttons, a Match Any/Match All picker shown once 2+ categories are selected, and a
capsule flow; plus the existing "Edit Categories" add/rename/delete screen) brought into
DailyFlightPlan, as the first concrete step of the larger Global Filter Sheet work.

**Presentation style, confirmed from screenshots (2026-10-03)**: in MapsPlus, the "Categories"
card is triggered by a top-right toolbar button and drops down anchored under it — it is *not* a
bottom sheet and *not* triggered by the floating bottom-right buttons (add-pin/navigate/list).
DailyFlightPlan's `FlightPlanView` already has a matching toolbar `tag`-icon button for this
(`showCategorySelector`); the only change needed there is presentation style: swap its current
`.sheet(...)` for a `.popover(isPresented:, attachmentAnchor: .point(.bottom), arrowEdge: .top)`
anchored to that button, with `.presentationCompactAdaptation(.popover)` so it drops down as a
card on iPhone too, instead of SwiftUI's default compact-width behavior of adapting `.popover` to
a full sheet.

**Key context that reshapes this plan**: the user is about to ship a fairly large tech refactor on
MapsPlus itself to enable iCloud/CloudKit sync there, which will change `LandmarkCategory` (e.g.
removing its `#Unique` constraint, since CloudKit doesn't support unique constraints) and likely
other details of the categories component. MapsPlus ships that refactor first. That means the
MapsPlus source already fetched during planning is a snapshot mid-flux, not a stable target worth
faithfully architecting DailyFlightPlan's persistence around right now.

**A previous attempt at this step was stashed after it crashed.** That attempt tried to faithfully
port MapsPlus's current design, including a real SwiftData `@Relationship` from a new
`SelectedPlanCategories` singleton to `PlanCategory` (with an inverse, to satisfy CloudKit's
"every relationship must be optional with an inverse" rule). It built and launched fine but then
crashed with `EXC_BREAKPOINT` on a plain `context.insert(...)` call during unit tests — isolated to
that new relationship specifically (confirmed other tests in this codebase already safely create
multiple overlapping-schema `ModelContainer`s in one process, so that wasn't the cause). Worth
remembering if SwiftData relationships come up again later, but not something to re-investigate now.

**Given MapsPlus's own design is about to change and ship first, the plan is:** build the same
basic UX here now with whatever persistence is simplest to get working today, treat it as
explicitly interim/throwaway, and later — once MapsPlus ships its CloudKit refactor and its
categories component stabilizes — pull *that* mature, shared-ready component into DailyFlightPlan,
replacing this interim implementation wholesale. Don't try to pre-architect for sharing now; that
work happens for real once there's a stable MapsPlus-side component to share.

## Decision: keep persistence simple, no new SwiftData model

Extend the **existing** UserDefaults-backed `CategorySelectionService` (`selectedNames:
Set<String>`) with a `filterMode` (matchAny/matchAll), also just persisted via UserDefaults/
`@AppStorage` — no new `@Model` type, no `ModelContainer` schema change, no CloudKit/relationship
risk at all. This is the fastest, lowest-risk path to "get the idea working," and sidesteps the
exact crash category hit previously by construction (there's no new relationship to misconfigure).

This persistence layer is explicitly throwaway: expected to be deleted and replaced wholesale once
MapsPlus's shared categories package is pulled into this project later. Don't over-invest
polishing or future-proofing it beyond "works correctly today."

## Scope

Only the category selector/editor component. Does **not** include: the floating filter button,
the General/Specific global sheet, search text, or per-tab toggle sections — those stay as already
documented in `global-filter-sheet-plan.md` for a later pass. This wires the new component into
`FlightPlanView`'s *existing* category-button/sheet entry point (replacing today's plain
capsule-row sheet), rather than building the bigger global sheet now.

## What gets built

1. **`Services/Categories/CategorySelectionService.swift`** — add to the existing UserDefaults-
   backed service:
   - A new small `enum CategoryFilterMode: String { case matchAny, matchAll }`.
   - `filterMode: CategoryFilterMode`, persisted via a new `AppStorageKeys.categoryFilterMode` case
     (stored as its raw string value in UserDefaults, same pattern `selectedNames` already uses).
   - `setFilterMode(_:)`, `shouldShowFilterModePicker` (true once 2+ categories are selected).
   - `filterItems(_:)` branches on matchAny (today's behavior, OR-logic) vs. matchAll (AND-logic).
   - Rename `clearAll()` → `clearAllSelections()` for clarity (not for cross-app-sharing purposes
     this time — just a readable name).

2. **`Views/Components/CategoryCapsule.swift`** — adopt the richer `isSelectable`/`Action`
   pattern (default params so existing call sites in FlightPlanView/TimelineView/CardDeckView keep
   compiling unchanged), styled via `DFPTheme.tintColor`/`.selectedCapsuleFontColor`/
   `.foregroundColor(for:)` (already present in `DFPTheme.swift`) instead of flat
   `.accentColor`/`.white`. Pure UI, no persistence dependency either way.

3. **New `Views/View Models/CategoriesSelectFlowViewModel.swift`** + **new
   `Views/Components/CategoriesSelectFlow.swift`** — thin wrapper + view matching MapsPlus's
   look: Clear/Edit header buttons, Match Any/Match All segmented picker (shown only when 2+
   categories selected) with a dismissible explanation (new `AppStorageKeys.
   showCategorySelectorExplanation` case), `HFlow` of `CategoryCapsule`s, an "Edit" button
   presenting the existing `CategoriesEditView` (unchanged — already matches MapsPlus's structure,
   no changes needed there).

4. **Wire into `Views/FlightPlanView.swift`**: replace the existing `categorySelectorSheet`'s
   VStack body with `CategoriesSelectFlow()`; remove the now-redundant `isShowingCategoriesEdit`
   state and `allCategories` query that only existed for the old sheet. Change the toolbar
   `tag`-icon button's presentation from `.sheet(isPresented: $showCategorySelector)` to
   `.popover(isPresented: $showCategorySelector, attachmentAnchor: .point(.bottom), arrowEdge:
   .top) { CategoriesSelectFlow() }.presentationCompactAdaptation(.popover)` so it drops down
   anchored to the button (matching MapsPlus) instead of sliding up as a full sheet. The "Edit"
   button inside `CategoriesSelectFlow` keeps presenting `CategoriesEditView` as a real `.sheet`
   (unchanged) — that's a full editing screen, not a quick dropdown.

5. **Tests**: extend `CategorySelectionServiceTests.swift` (still UserDefaults-based, as it
   already is) with filter-mode coverage; add `CategoriesSelectFlowViewModelTests.swift`.

## Verification

- `BuildProject` after each step, not only at the end.
- `RunAllTests` once wired up — no SwiftData/CloudKit risk this time, so this should be low-drama.
- `RunProject` + manual tap-through of the category selector sheet (select/clear/match-any/
  match-all/edit) in the simulator.

## Not in this plan (deferred)

- The floating filter button, General/Specific global sheet, search text, per-tab toggle
  sections — tracked separately in `global-filter-sheet-plan.md`.
- Pulling the real shared categories package from MapsPlus — explicitly gated on MapsPlus shipping
  its CloudKit/iCloud-sync refactor first and that component stabilizing there. This interim
  DailyFlightPlan implementation is expected to be replaced at that point, not maintained
  long-term.
- SwiftData-backed persistence or relationship modeling for category selection in this app — not a
  goal right now; likely moot once the shared package replaces this layer later anyway.
