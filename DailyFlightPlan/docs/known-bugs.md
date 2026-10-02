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
