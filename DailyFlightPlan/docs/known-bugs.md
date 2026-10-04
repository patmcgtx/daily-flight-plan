# Known Bugs

Specific defects — not roadmap items or polish ideas (those stay in `implementation-plan.md`).
When one is fixed, move its entry from **Open** to **Fixed** rather than writing the fix up in
`implementation-plan.md` — keeps the phase narrative there focused on features, not bug-fix prose.

## Open

- **AI summary still occasionally misreports item status**: since the `(done)` marker was added
  to the Day-view section-summary prompt (`DayViewModel.generateSummaryIfNeeded`, Phase 1.14), the
  on-device model sometimes describes a still-*open* item as completed (the inverse of the original
  "Yes"-junk complaint fixed in the same phase). Likely needs either a stronger prompt structure
  (e.g. separate "Done:" / "Open:" clauses instead of one inline-marked list) or a deterministic
  non-LLM fallback for status wording.

- **Completed/canceled items still accept context menu actions**: pills in the done or cancelled
  rows still show the "Cancel Item" context menu action. Fix: gate the context menu's destructive
  action in `ItemPillView` on `item.status == .pending`.

- **Crash on delete-all-items**: deleting all items triggers a crash. Not yet root-caused.

## Fixed

- **Stale Day-view section summary after content changes** *(Phase 1.14)*: the cached AI summary
  for a section (`FlightPlanView`/`CardDeckView`) was only cleared on date change, so moving an
  item into/out of a section, canceling it, or editing its title/deadline left the old summary
  showing. `DayViewModel` now tracks a per-section `contentSignature` (item id/status/title/deadline
  + event/reminder id/time) and `refreshSummaryIfNeeded(for:items:events:reminders:)` clears and
  regenerates the summary whenever that signature changes; wired via `.onChange(of: contentSignature)`
  alongside the existing `.onAppear` trigger in both section-card views.

- **Nonsensical summaries (e.g. "Yes") for mostly/fully completed segments** *(Phase 1.14)*:
  `generateSummaryIfNeeded` only fed `status == .pending` items to the model, so a section with
  everything checked off (or only one pending item left) produced a near-empty prompt, which the
  on-device model answered with junk. Now completed items are included too (marked `(done)` in the
  prompt so the model doesn't describe them as upcoming) — only canceled items are excluded. Also
  added a `guard !parts.isEmpty` so a section with genuinely nothing to say (e.g. only canceled
  items) skips the model call instead of prompting it with an empty string.

- **Swiped-away dates could clobber the selected day's section summary** *(Phase 1.14, found via
  Copilot review)*: `FlightPlanView`'s `TabView` keeps the previous/selected/next-day pages mounted
  simultaneously for swipe transitions, but the summary cache is keyed only by `DaySection` — so an
  offscreen adjacent-day page's `onAppear`/`onChange` could overwrite the visible day's cached
  summary with its own content. `sectionCard` now computes `isSelectedDate` and gates both triggers
  on it, so only the page matching `viewModel.selectedDate` touches the cache.

- **Canceled/stale summary generation tasks could corrupt newer ones** *(Phase 1.14, found via
  Copilot review)*: `clearSummary` canceled the in-flight task and immediately let
  `refreshSummaryIfNeeded` start a replacement, but `Task.cancel()` is cooperative — the old task's
  `defer` (and a non-cooperative `session.respond` call) could still run afterward, clearing the
  new task's `summaryTasks`/`loadingSummarySections` entries out from under it, or overwriting its
  result with a stale response. `DayViewModel` now stamps each task with a
  `summaryGenerations[section]` UUID; the `defer` and the response-publishing step both check that
  their generation is still current before mutating shared state.

- **Completed reminders missing the `(done)` marker in summaries** *(Phase 1.14, found via Copilot
  review)*: when "Show Completed" is on, completed reminders reach the summary prompt (both timed
  and untimed) alongside pending ones, but only `PlanItem`s were getting the `(done)` label — a
  finished reminder looked identical to an upcoming one, undermining the fix above. Both reminder
  loops in `generateSummaryIfNeeded` now mark `reminder.isCompleted` the same way.

- **`filterMode` changes didn't trigger view updates** *(Phase 2.5, found via Copilot review)*:
  `CategorySelectionService.filterMode` was computed directly from `UserDefaults` on every access,
  so `@Observable` had no stored property to track — changing the mode via the Match Any/Match All
  picker could leave both the picker's own selection and `filterModeExplanation` stale until an
  unrelated redraw. Added a `storedFilterMode` stored property that `filterMode`'s getter/setter
  read/write (persisting to `UserDefaults` as a setter side effect), giving `@Observable` something
  to actually track.

- **`CategoryCapsule` lost button semantics for assistive tech** *(Phase 2.5, found via Copilot
  review)*: the selectable capsule used `.contentShape(Rectangle()).onTapGesture { ... }` instead
  of a real `Button`, so VoiceOver/Switch Control/keyboard users saw it as static text even though
  tapping it changed filter state. Restored a real `Button` for the selectable path (with
  `.accessibilityAddTraits(.isSelected)` exposing selection state), rendering the non-selectable/
  action variant separately.

- **`FilterToolbarButton` ignored the Day tab's Calendar/Reminders toggles** *(Phase 2.5, found via
  Copilot review)*: `isFilterActive` for `.flightDeck` checked `showCompleted`/`showRecurring` but
  not `showCalendarEvents`/`showReminderItems` — turning either off hides content but left the
  toolbar icon unfilled. Added both as `@AppStorage` reads and included `!showCalendarEvents ||
  !showReminderItems` in the active-state check.

- **Routine tab's "Flagged Only" toggle didn't filter routines** *(Phase 2.5, found via Copilot
  review)*: the General section's "Flagged Only" toggle is shown (and reported as active) on the
  Routine tab, but `RoutineView`'s `filteredTemplates` only applied search and category filters, so
  unflagged routines stayed visible regardless. Added a `showFlaggedOnly` `@AppStorage` read and an
  `isFlagged` filter clause, matching Day and Timeline.

- **Timeline's whitespace-only search desynced from Day/Routine** *(Phase 2.5, found via Copilot
  review)*: `matchingSearchText(_:)` treats whitespace-only input as empty (no-op), but
  `TimelineView` still branched on the raw `searchText.isEmpty` for its day-windowed vs.
  search-results view switch and the "Go to Today" button's disabled state. Entering only spaces
  left Day/Routine unfiltered while Timeline switched to an empty search-results screen. Added a
  single `trimmedSearchText` computed property and used it everywhere Timeline checks for an empty
  query.

- **`CategorySelectionServiceTests` and `CategoriesSelectFlowViewModelTests` could race each other**
  *(Phase 2.5, found via Copilot review)*: both suites declared `@Suite(.serialized)`, but that only
  serializes tests *within* a suite, not across suites — both mutated and restored the same real
  `UserDefaults.standard` keys, so either suite could restore state mid-mutation of the other,
  producing flaky failures if the runner executed suites concurrently. Made `UserDefaults`
  injectable on `CategorySelectionService` (`init(defaults: UserDefaults = .standard)`, production
  call sites unaffected) and rewrote both test files to each use a fresh, uniquely-named
  `UserDefaults(suiteName:)` domain per test instead of sharing `.standard` — `.serialized` is no
  longer needed on either suite.
