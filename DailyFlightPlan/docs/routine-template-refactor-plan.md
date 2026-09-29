# Split `PlanItem` into `RoutineTemplate` + `PlanItem`

## Context

While fixing the drag-and-drop duplicate-item bug and consolidating item-identity logic, we
kept running into the same root cause: one `@Model class PlanItem` (`PlanItem.swift`) plays
**three different roles** via flags — a recurring template (`isTemplate == true`), a per-day
instance generated from a template (`template != nil`), and a one-off item (`template == nil`).
Every bug we found and fixed today (`coversRecurringOccurrence`, `instanceDedupeKey`,
`deduplicateInstances`) was some piece of code accidentally treating one role as another because
nothing at the type level prevents it.

Since the app hasn't shipped, there's no CloudKit schema-migration cost to worry about — this is
a good time to split the type properly: a dedicated `RoutineTemplate` model for the schedule
definition, and a slimmed `PlanItem` for one-off items and per-day instances only. This removes
the conflation at its source instead of continuing to patch call sites one at a time.

Decisions already made with the user:
- **No in-form promote/demote.** `ItemForm` will only ever edit `PlanItem` (one-off + instance) —
  no recurring-weekday picker at all. `RoutineView` gets its own new `RoutineForm` for creating/
  editing `RoutineTemplate`s. Converting between the two becomes a manual delete-and-recreate.
- **Delete `DayView.migrateOldRecurringItems()`** entirely rather than adapt it — it migrates data
  from before the current template model even existed (Phase 1.15), and there are no shipped
  users who could still have it.

## New model shape

**`RoutineTemplate`** (new `@Model`, in `Persistence/RoutineTemplate.swift`): `sourceID`, `uuid`
(drag token, used by `RoutineView`'s cross-card reassignment), `title`, `notes`, `isFlagged`,
`deadline` (time-of-day), `daySection`, `recurringWeekdays`, `categories`,
`instances: [PlanItem]?` (`@Relationship(deleteRule: .nullify, inverse: \PlanItem.template)`).

**`PlanItem`** (`Persistence/PlanItem.swift`, slimmed): drops `isTemplate` and `recurringWeekdays`
entirely; `template` becomes typed `RoutineTemplate?` instead of self-referential. Keeps
`sourceID`, `uuid`, `title`, `notes`, `isFlagged`, `date`, `deadline`, `daySection`, `status`,
`categories`, `reminderIdentifier`. `isRecurring` simplifies to `template != nil`.
`instanceDedupeKey` and `coversRecurringOccurrence(ofTemplate: RoutineTemplate, on:)` keep their
current logic, just type-checked against `RoutineTemplate` instead of a same-typed "template".

## File-by-file plan

**Persistence**
- `PlanItem.swift`: remove `isTemplate`, `recurringWeekdays`, `instances`; retype `template`.
- New `RoutineTemplate.swift`: the model above.
- `ModelContainers.swift`:
  - Register `RoutineTemplate.self` in both `persistentContainer()` and `inMemorySampleContainer()`.
  - `deduplicateItems` → rename `deduplicateTemplates`, fetch `RoutineTemplate` directly (no
    `isTemplate` filter needed), same sourceID → content-key merge passes.
  - `deduplicateInstances`: fetch `PlanItem` directly (already all instances/one-offs), same
    `instanceDedupeKey` logic.
  - `templateContentKey(_ item: RoutineTemplate)`: retype parameter only.
  - New `deleteAllTemplates(in:)`: fetch + delete `RoutineTemplate`; the nullify-inverse
    relationship should auto-clear `instance.template` on each deleted template's instances, so
    this likely doesn't need `deleteAllItems`'s two-phase nil-out dance — verify during
    implementation and simplify `deleteAllItems` similarly if the self-reference was the only
    reason for the two-phase save there.
  - `seedSampleDataIfNeeded` / `inMemorySampleContainer`: construct `RoutineTemplate(...)` instead
    of `PlanItem(..., isTemplate: true)`.

**Core view models**
- `DayViewModel.swift`: `recurringInstancesToMaterialize(templates: [RoutineTemplate], ...)` and
  `projectedRecurringItems(from templates: [RoutineTemplate])` retype their `templates` param.
  `projectedRecurringItems` currently returns the qualifying templates themselves (as `PlanItem`)
  for display at reduced opacity — since it can no longer return `RoutineTemplate` and have
  `ItemPillView` render it, have it construct **transient, never-inserted** `PlanItem` copies from
  each qualifying template (same field-copy shape `recurringInstancesToMaterialize` already uses
  when actually materializing — factor a shared private helper). This keeps `DaySectionView` /
  `ItemPillView` completely untouched.
- `DayView.swift`: `recurringTemplates` query retypes to `[RoutineTemplate]`, no predicate needed.
  Delete `migrateOldRecurringItems()` and its call site. `materializeRecurringInstances(for:)`
  splits its single dual-filtered fresh-fetch into two `FetchDescriptor` calls (one per type).
  Settings' delete-all-items sheet-dismiss handler must call both `deleteAllItems` and the new
  `deleteAllTemplates` to preserve today's "wipe everything" behavior.

**Templates-only screen**
- `RoutineView.swift`: `@Query` retypes to `[RoutineTemplate]`, no predicate. `deleteTemplate`
  likely simplifies (see `deleteAllTemplates` note above). Presents a new `RoutineForm` instead of
  reusing `ItemForm`.
- New `RoutineForm.swift` + `RoutineFormViewModel.swift`: mirrors `ItemForm`/`ItemFormViewModel`'s
  structure but scoped only to `RoutineTemplate` fields (title, notes, flagged, day section,
  time-of-day deadline, weekday picker, categories) — no "kind" branching at all, since it only
  ever edits one type.

**Item-editing screen**
- `ItemForm.swift` / `ItemFormViewModel.swift`: remove the recurring-weekday picker section,
  `isEditingTemplate`/`willDemoteTemplate`, the `init(templateWeekdays:section:)` initializer, and
  the promote/demote branches in `save()`. Remaining scope: create/edit one-off `PlanItem`, edit
  instance `PlanItem` (schedule still not editable on an instance, same as today).

**Display-only / mechanical call sites** (all follow the same two changes: drop `isTemplate ==
false` from any `@Query`/`FetchDescriptor` predicate since every `PlanItem` is already an instance
or one-off now; `item.isRecurring` keeps working unchanged since it's still a computed property)
- `TimelineView.swift`, `CardDeckView.swift`, `FlightPlanView.swift`: predicate simplification only.
- `DaySectionView.swift`, `DeadlineItemRow.swift`, `ItemPillView.swift`: no changes needed beyond
  `isRecurring`'s implementation already being handled in `PlanItem.swift`.
- `MarkdownImportView.swift`: `commit(to:on:)`'s single branch that builds either a template or a
  one-off `PlanItem` splits into constructing `RoutineTemplate(...)` vs `PlanItem(...)`.
- `CommView.swift`: `templates` query retypes to `[RoutineTemplate]`; `CommViewModel.buildContext`
  retypes its `templates` param; the `CreateItemTool`/`onItemsCreated` handler splits its
  constructor branch the same way as `MarkdownImportView`.

**Tests**
- `PlanItemTests.swift`: update `coversRecurringOccurrence`/`instanceDedupeKey` tests to construct
  `RoutineTemplate` for the template side (same assertions, new type).
- `DayViewModelTests.swift`: split the local `item(...)` helper into `item(...)` (`PlanItem`) and a
  new `template(...)` (`RoutineTemplate`); retype `templates:` arguments accordingly.
- `ModelContainersTests.swift`: rename `deduplicateItems*` tests to `deduplicateTemplates*`,
  construct `RoutineTemplate` directly; add a `deleteAllTemplatesRemovesEverything` test; update
  seed/in-memory-container assertions to check `RoutineTemplate` non-empty and `PlanItem` empty
  (seed data is templates only — no pre-materialized instances).
- `ItemFormViewModelTests.swift`: remove all promote/demote and template-editing tests
  (`willDemoteTemplate`, `initForTemplateShowsRecurringWeekdays`, `saveDemotesTemplateAndSevers
  Instances`, `savePromotesOneOffToTemplate`, etc.) — `ItemForm` no longer touches templates.
- New `RoutineFormViewModelTests.swift`: the template-editing coverage removed above, relocated
  and simplified (no "kind" branching to test anymore).

## Verification

- After each phase, `XcodeRefreshCodeIssuesInFile` the touched files and `RunAllTests` — expect 0
  failures among the ~170 non-UI tests (the 3 UI tests are environment-gated, unrelated).
- Manual smoke test via `RunProject`/simulator: create a one-off item; create a routine; drag an
  item between day sections and confirm no duplicate reappears later (the original reported bug);
  confirm Comm chat's "Upcoming" ghost projections still show for future days; confirm dragging a
  routine pill between weekday-pattern cards in `RoutineView` still works; confirm Settings'
  "delete all items" wipes both one-offs and routines.

Given the size (2 new files, ~15 touched files, several test files rewritten), recommend landing
this as a sequence of commits by phase (persistence → core view models → RoutineView/RoutineForm →
ItemForm → mechanical call sites → tests) rather than one large diff.
