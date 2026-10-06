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

- **SwiftData property-set overhead on `PlanItem.status`**: Time Profiler showed `PlanItem.status`'s
  setter itself (not app code around it) spending real time in SwiftData's generic runtime
  type-resolution path (`swift_getTypeByMangledNameImpl` and friends) — a known SwiftData
  characteristic, not something fixable from the call site. Contributed to the completion-tap hang
  investigated below; the fix there reduced the *compounding* work riding on the same render pass,
  but this specific cost is a platform floor. Revisit if a future SwiftData/OS release changes this.

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

- **Filter popover rendered full-screen with no dismiss on iPhone** *(Phase 2.5)*:
  `FilterToolbarButton`'s `.popover(...)` was believed to have a genuine OS-level
  `.presentationCompactAdaptation(.popover)` bug on this project's iOS 27 beta (see the now-stale
  `popover-compact-adaptation-bug` memory) and fell back to a `.presentationDetents` sheet instead.
  Re-examined after the user pointed out MapsPlus achieves a true anchored popover on the same
  Xcode/iOS version — turned out not to be an OS bug: MapsPlus's working popover passes an explicit
  `attachmentAnchor`/`arrowEdge` and a `.frame(minWidth:idealWidth:maxWidth:)` on its content,
  neither of which `FilterToolbarButton` had. Added both, which fixed the full-screen/no-dismiss
  symptom — but then exposed a second issue: `FilterSheetView`'s content is a `NavigationStack {
  Form { ... } }`, and unlike MapsPlus's plain-stack content, `Form`/`List` has no intrinsic height
  for the popover sizing system to read, so the popover collapsed to just its ~68pt nav bar with
  the width-only frame. Fixed by adding explicit height bounds to the same `.frame(...)` call
  (`minHeight: 400, idealHeight: 500, maxHeight: 600`). Verified via on-device checks on Day,
  Timeline, and Routine that the popover now renders at full size with all Form content visible,
  and that both tap-outside and Done-button dismiss still work.

- **Responsiveness sprint (startup freeze, slow item completion, sluggish scroll/search)**: user
  reported the Day view feeling sluggish on a real iPhone 16 — items took 2-4s to visibly complete,
  launch froze for several seconds, scrolling lagged, and typing in search felt unresponsive. The
  simulator couldn't reproduce any of it (CloudKit sync and on-device Apple Intelligence summaries,
  both likely contributors, are no-ops there), so the user captured a real Time Profiler trace on
  the device, which located the actual hangs (13 of them, ~8s total) with full call stacks pointing
  at two concrete, fixable causes — plus one inherent SwiftData cost logged separately in Open.
  1. `DayView.recurringTemplates.getter` was on-stack during a 1.1s startup hang:
     `recurringTemplates`/`allItems` were live `@Query`s used *only* for migration/dedup bookkeeping
     (never rendered), but `DayView.body` paid SwiftData's CoreData `performAndWait`/`valueForKey:`
     cost for them on every single render, not just when the data changed. Removed both `@Query`s;
     `migrateOldRecurringItems()` now does its own one-time `context.fetch` (matching the pattern
     `materializeRecurringInstances` already used). The "a routine template changed" signal that
     used to ride on `.onChange(of: recurringTemplates.count)` is now an explicit
     `\.recurringTemplatesChanged` environment closure that `RoutineView` calls directly via
     `onDismiss` on its two routine-editing sheets.
  2. `FlightPlanView.sectionCard`/`progressRow` each independently called `activeItems(for:)`/
     `rawItems(for:)` (full Calendar-filtering passes over every item) despite neither actually
     depending on `section` — multiplying one expensive operation by ~13x per visible day (3 swipe
     pages × 6 sections × up to 2 calls, plus `progressRow`). Hoisted both to a single computation
     per date in `dayContent(for:)`, passed down as parameters. `TimelineView.groupedByDate` had the
     same shape of bug — a computed property re-filtering/re-grouping from scratch on every access,
     read up to 4x per visible row during scroll (`ForEach` plus `.count`/`.first`/`.last` in
     `onAppear`) — fixed by hoisting it to a single `let groups = groupedByDate` per render.
  Verified via build + a correctness smoke test (adding a routine still immediately materializes
  today's instance via the new signal) and user-confirmed on-device as "a lot more responsive."
  `PlanItem.status`'s setter itself still has real SwiftData overhead — see the matching Open
  entry above; this fix reduced what compounds on top of it, not the floor itself.
  **Follow-up (found via Copilot review)**: removing the `@Query`-driven trigger also removed the
  only path that reconciled today's templates after a *CloudKit-delivered* template change — the
  local sheet-dismissal signal only fires for edits made in this app's own `RoutineView`, and the
  `scenePhase`-active handler only dedupes, never materializes. A template synced in from another
  device while the app was already open on today, with no local sheet interaction, would silently
  never get today's instance. Added a `.onReceive` on
  `NSPersistentCloudKitContainer.eventChangedNotification`, filtered to successful `.import`
  events, that reconciles via the same `handleRecurringTemplatesChanged()` — debounced 500ms
  (`scheduleRecurringTemplatesReconcile()`) since a sync can deliver several import events in quick
  succession and each one doesn't need its own full reconcile pass.
