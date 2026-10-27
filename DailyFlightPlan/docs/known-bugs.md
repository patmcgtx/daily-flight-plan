# Known Bugs

Specific defects — not roadmap items or polish ideas (those stay in `implementation-plan.md`).
When one is fixed, remove its entry outright rather than writing the fix up here or in
`implementation-plan.md` — commit history/messages are the record of what was fixed and when;
this file only tracks what's still outstanding. **Open** is for defects that have actually been
reproduced; a report that hasn't been reproduced yet goes in **Unverified Reports** instead, and
only moves to **Open** once someone reproduces it.

## Unverified Reports

Not yet reproduced — each entry needs the affected action, device/OS, and observed result filled
in (or confirmed) before it can be investigated as a real defect.

- **Deep links to Reminders/Calendar reportedly broken**: affected action unclear — could be the
  `x-apple-reminderkit://` row-tap deep link added in Phase 0.1.19, or the `calshow:` tap added in
  Phase 0.1.7; device/OS not specified; observed result not specified (nothing happens? wrong app?
  wrong item? crash?). Reproduce with those specifics before moving to Open.

- **App sometimes opens to the Routine tab instead of the intended default**: affected action is
  app launch; device/OS not specified; observed result is landing on the Routine tab instead of
  the Cockpit tab, which is `DayView.activeTab`'s declared initial value. Reported as
  intermittent. Hypothesis worth checking once reproduced: `@State private var activeTab`
  retaining a prior `.routines` value across scene restoration/relaunch instead of starting
  fresh at `.cockpit`. Reproduce reliably (and note device/OS) before moving to Open.

- **Mac hang/crash on the Timeline view**: the macOS build hangs or crashes while using the Timeline tab. Exact trigger, macOS version, and whether it's a hang vs. a crash are not yet recorded; not yet root-caused.


## Open

- **AI summary still occasionally misreports item status**: since the `(done)` marker was added
  to the Day-view section-summary prompt (`DayViewModel.generateSummaryIfNeeded`, Phase 0.1.14), the
  on-device model sometimes describes a still-*open* item as completed (the inverse of the original
  "Yes"-junk complaint fixed in the same phase). Likely needs either a stronger prompt structure
  (e.g. separate "Done:" / "Open:" clauses instead of one inline-marked list) or a deterministic
  non-LLM fallback for status wording.

- **Completed/canceled items still accept context menu actions**: pills in the done or cancelled
  rows still show the "Cancel Item" context menu action. Fix: gate the context menu's destructive
  action in `ItemPillView` on `item.status == .pending`.

- **Crash on delete-all-items**: deleting all items triggers a crash. Not yet root-caused.

- **Tests that spin up a real `ModelContainer` crash intermittently under parallel test
  execution**: individual tests in `CategoriesEditViewModelTests` (e.g.
  `addCategoryInsertsTrimmedName()`, `deleteCategoryRemovesFromStore()`) and `ModelContainersTests`
  (e.g. `seedSampleDataInsertsWhenEmpty()`, `deduplicateInstancesRemovesDuplicatesKeepingOne()`)
  abort mid-run (`libsystem_c.dylib: abort() called` inside `Runner._applyScopingTraits`),
  reproducible even running just one affected suite in isolation. The console log shows
  CloudKit-mirroring teardown races ("store was removed from the coordinator") on an in-memory
  `ModelContainer` right before each crash — looks like parallel test workers tearing down one
  container's CloudKit mirroring delegate while another test in the same worker process is still
  using a different container. Not specific to either suite's own logic (both suites' other tests,
  and every suite that doesn't touch `ModelContainer` — including `ModelContainerTests`-adjacent
  pure-function suites like the new `RoutineMarkdownExporterTests`/`DayPlanMarkdownExporterTests`
  — pass reliably). Not yet root-caused; found while running the full suite during unrelated
  Markdown-export work.

- **Cockpit tab's date-picker sheet looks undersized on macOS**: `DatePickerToolbarButton`
  presents via `.sheet` on macOS (`.popover` attached to a toolbar button there never opens at
  all — a separate issue, worked around by branching to `.sheet`), with the content frame fixed
  to `width: 300` and no height constraint so the sheet sizes to the native graphical
  `DatePicker`'s small native footprint. Still looks noticeably smaller/plainer than the iOS
  popover version even after that sizing pass — functional (Today + calendar grid + Close button
  all work), just visually imperfect. Not pursued further since it's a minor, low-traffic
  surface; revisit if it bugs someone enough to be worth another pass.

- **SwiftData property-set overhead on `PlanItem.status`**: Time Profiler showed `PlanItem.status`'s
  setter itself (not app code around it) spending real time in SwiftData's generic runtime
  type-resolution path (`swift_getTypeByMangledNameImpl` and friends) — a known SwiftData
  characteristic, not something fixable from the call site. A prior responsiveness-sprint fix
  reduced the *compounding* work riding on the same render pass, but this specific cost is a
  platform floor. Revisit if a future SwiftData/OS release changes this.

