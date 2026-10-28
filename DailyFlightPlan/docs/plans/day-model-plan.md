# Day model plan (flight name + intention)

Persists the per-day flight name and "destination" (intention) note that the Cockpit tab lets the
user edit. Shipped in three verified steps, in line with the incremental-persistence approach used
for the category selector.

## Model

`Day` (`Persistence/Day.swift`), a CloudKit-synced `@Model`:

- `date: Date` — start-of-day lookup key, normalized in `init` via `Day.normalized(_:)`.
- `flightName: String` — `""` means "use the default `DFP YYYYMMDD` number".
- `intention: String` — the day's note; `""` means none.
- `modifiedAt: Date` — stamped by `setFlightName(_:)` / `setIntention(_:)`; used to pick a winner
  when merging duplicates.

Design choices:

- **No relationship to `PlanItem`.** Items match a day by date, so the model stays clear of
  CloudKit's optional + inverse relationship rules.
- **Created lazily.** A row exists only after the user customizes something; a row left with
  nothing customized is deleted (`Day.isBlank`).
- **All properties have defaults, no unique constraint** (CloudKit rules).

## Duplicates

CloudKit can't enforce uniqueness, so two devices can each create a row for the same date.
`ModelContainer.deduplicateDays(in:)` keeps the most recently modified row per day and fills its
blank fields from older rows; a row left with nothing customized is deleted. It runs at launch,
on returning to the foreground, and from Settings' Deduplicate action.

Settings' "delete items" does not touch `Day` rows: its alert only mentions items and routines,
and silently deleting custom flight names and intentions would be unexpected data loss.

## UI wiring (`CockpitView`)

- `@Query` supplies days for display; writes go through a context fetch (`dayForEditing`) so
  rapid edits can't insert a second row before the query refreshes.
- The flight name field binds to a `@State` draft that mirrors the displayed flight number while
  unfocused and holds the raw text while editing. This lets the field be emptied without snapping
  back, and avoids rewriting the field's text when focus begins (an earlier seeding approach
  dropped a character).
- Text equal to the default number (or blank) is stored as `""`.
- The Markdown export reads the same `Day` row.

## Verification

- Unit tests: `DayTests`, plus the `Day` cases in `ModelContainersTests`.
- On the iPhone 17e simulator: edits to both fields survive an app relaunch; clearing the flight
  name and ending editing restores the default; editing mid-text keeps all characters.

## Not done

- No UI for "Type of Flight" / "Flight Rules"; they could become more fields on `Day`.
- A Settings option (with its own confirmation) to delete day customizations; there is currently
  no way to delete them in bulk.
