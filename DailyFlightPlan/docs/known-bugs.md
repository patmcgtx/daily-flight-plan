# Known Bugs

Open, specific defects — not roadmap items or polish ideas (those stay in `implementation-plan.md`). Remove an entry once it's fixed (the fix itself gets noted in `implementation-plan.md` under the relevant phase).

- **AI summary still occasionally misreports item status**: since the `(done)` marker was added to the Day-view section-summary prompt (`DayViewModel.generateSummaryIfNeeded`, Phase 1.14), the on-device model sometimes describes a still-*open* item as completed (the inverse of the original "Yes"-junk complaint fixed in the same phase). Likely needs either a stronger prompt structure (e.g. separate "Done:" / "Open:" clauses instead of one inline-marked list) or a deterministic non-LLM fallback for status wording.

- **Completed/canceled items still accept context menu actions**: pills in the done or cancelled rows still show the "Cancel Item" context menu action. Fix: gate the context menu's destructive action in `ItemPillView` on `item.status == .pending`.

- **Crash on delete-all-items**: deleting all items triggers a crash. Not yet root-caused.
