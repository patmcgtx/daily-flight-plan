# Daily Flight Plan — Functional UI Spec (for Figma design exploration)

This document lists the current, *implemented* user-facing behavior of the app, broken down by
tab and shared screen. It's meant to be fed into a design tool to generate new visual treatments
for existing functionality — it is not a roadmap and does not include unbuilt ideas.

The app has three tabs, in this order: **Day**, **Routine**, **Timeline**.

## Shared concepts (apply across tabs)

### Items
- An item has: a title, optional notes, a flagged (important) flag, a date, an optional specific
  clock-time deadline, an optional day-section assignment, zero or more categories, a status
  (pending / completed / canceled), and a recurring flag.
- **Day sections** (fixed, not yet user-customizable): First Thing (before 7:30 AM), Morning
  (7:30–11 AM), Midday (11 AM–1 PM), Afternoon (1–5 PM), Evening (5–10 PM),
  Bedtime (10 PM–midnight).
- An item with no deadline and no day section is "Open" (any-time).
- **Recurring items ("routines")** are stored as a template; a per-day instance is created
  automatically for today only. Past days show any historical instances that were created for
  them; future days currently show only one-off items.
  Instances are independent — completing/canceling/editing one doesn't affect the template or
  other days.

### Item visual treatment
Visuals vary by tab and row type; status icons and badges are not shared across all item rows.
- **Day task pills**: pending items show a hollow circle; completed and canceled items have no
  status icon. Non-pending titles are struck through and secondary-colored. Notes show a
  "note.text" icon, and flagged items show a red filled flag. Routine pills are grouped under an
  infinity label instead of showing a second infinity badge.
- **Day deadline rows**: show an outlined circle with a checkmark inside when completed; completed
  titles are struck through and secondary-colored. Flagged items show an orange filled flag.
  These rows do not show notes or recurring badges, and cancellation has no distinct visual state.
- **Routine templates**: timed rows and untimed pills have no completion-status control. Both show
  an orange filled flag when flagged and a "note.text" icon when notes exist.
- **Timeline rows**: pending items show a hollow circle, completed items a filled checkmark-circle,
  and canceled items an unfilled X-circle. Completed and canceled titles are struck through;
  canceled titles are secondary-colored. Flagged items show a red filled flag and items with notes
  show a "note.text" icon. Recurring items have no badge.
- **Calendar events** and **Reminders** use full-width external rows: italic title, leading 3pt
  colored bar matching the source calendar/list color, and an "arrow.up.right.square" icon.
  Tapping opens the system Calendar/Reminders app. Reminders additionally offer "Import as Task"
  via context menu, which copies the reminder into the app as a one-off item.
- The item-pill component has an optional missed-state treatment, but active Day pills are not
  passed that state and Timeline rows do not display a missed indicator.

### Item interactions
- **Day task pills**: tap to edit; the pending circle marks the item complete. Their context menu
  offers "Cancel Item" and, for non-recurring items only, "Defer to Tomorrow" (shifts the date and
  deadline by one day).
- **Day deadline rows**: the circle control toggles pending/completed; the context menu offers
  Edit and Cancel. They do not have an active swipe-to-cancel/defer gesture.
- **Routine templates**: tap to edit; the context menu offers Edit and Delete.
- **Timeline rows**: tap the title to edit; the checkbox toggles pending/completed and does nothing
  once canceled. The context menu offers Edit and Cancel.
- **Drag-and-drop**: Day pills can be dragged onto another section card to reassign the item's day
  section (and clear any deadline). Routine templates can be dragged between segments or schedule
  cards to reassign the day section or weekday pattern. Drop targets highlight with an
  accent-colored border while dragging.

### Add/Edit item sheet ("Item Form")
Presented for creating a new item, creating a new routine, or editing an existing item/template.
Fields, in order:
1. Title (text field)
2. Notes (multi-line text field)
3. Date picker (creation only — hidden when editing an existing per-day instance)
4. "Flagged" toggle (red tint, flag icon)
5. "Specific Time" toggle — when on, shows a time picker (deadline); when off, shows a "Segment"
   picker (Open + the six day sections)
6. "Recurring" section (hidden when editing an existing instance) — "Make it a routine" label plus
   a row of 7 tappable day-letter circles (Su M T W Th F Sa) to pick the weekday pattern
7. "Categories" section (hidden if no categories exist) — tappable rows per category with a
   checkmark when selected
- Turning off "Recurring" days on an existing template (demoting it) shows a confirmation alert
  ("Stop Repeating?") warning that past completions become standalone items.
- Save is disabled until the form is in a valid state (non-empty title).

### Filters
- A single global filter sheet ("Filters"), opened from a filter toolbar button present on every
  tab; the button visually fills/accents when any filter is active.
- **General** section (applies on every tab): category multi-select (tap capsules to toggle;
  "Clear" and "Edit" buttons; a Match Any / Match All segmented picker appears once 2+ categories
  are selected, with a dismissible one-line explanation of what each mode does), and "Flagged
  Only" toggle.
- **Per-tab "Specific" section**, contents depend on which tab opened the sheet:
  - **Day**: Show Completed, Routines (on/off), Calendar Events (on/off), Reminders (on/off)
  - **Timeline**: Completed Only / Missed Only (mutually exclusive toggles)
  - **Routine**: no tab-specific toggles
- Each tab additionally has its own lightweight inline **search field** (toggled by a search
  toolbar icon, not part of the filter sheet), filtering that tab's visible content live as you
  type.
- All filter/search state persists via `@AppStorage` and is shared across tabs (except search
  text, which is local per tab).

### Settings sheet
Currently a minimal/developer-oriented screen, opened via the gear icon on the Day tab:
"Seed Sample Data," "De-duplicate Items," "Delete All Items" (destructive, confirms via alert),
"Delete All Categories" (destructive, confirms via alert). Footer notes deletions sync via iCloud.
This is a placeholder for future user-facing preferences (e.g. customizing day-section times).

### Categories
- Free-form text tags (no color/icon), managed in a dedicated "Edit Categories" sheet: add via a
  text field, rename inline, delete via swipe with a confirming alert ("removed from all items").
  Each row shows an item count.
- Assigned to items via the multi-select list in the Item Form.
- Used only for filtering today (not shown as a persistent badge/capsule on item rows themselves).

### Theme
- A theme menu (icon button, Day tab toolbar) lets the user switch between theme options
  (`DFPTheme`, Cupertino being the default/system-color option); selection is instant and applies
  app-wide.

## Tab 1: Day ("Flight Plan" or "Cockpit")

The primary, default-landing tab. Airplane icon.

### Layout
- Sticky (non-scrolling) top toolbar: Settings (gear, leading), Import (arrow-down-doc, leading);
  trailing group: "Go to Today" (scope icon, disabled when already on today), search toggle,
  filter button, theme menu.
- Swipeable horizontal pager: three pages (yesterday / today / tomorrow). Swiping left/right
  navigates days and the pager silently re-centers after each swipe so it always has a fresh
  adjacent page ready (infinite paging illusion). On macOS, a drag gesture replaces the page
  swipe.
- Each day page scrolls vertically and contains, top to bottom:
  1. Date label ("Today" in accent color, or weekday name; month/day below in bold)
  2. One card per day section, in section order
  3. An "Open" (any-time) card, shown only if it has content
  4. A progress row: small ring + "`N` of `M` complete" / "All done!" / "No items planned" text
- A floating circular "+" button (bottom-trailing, glass style) opens the Item Form for a new
  one-off item dated to the currently viewed day.

### Section cards
- Rounded-rect card (18pt corner radius), subtle shadow, 0.5pt border (thicker/accent-colored
  when it's the current time-of-day section on today).
- **Collapsed**: header only — section name, item count badge, "`completed`/`total`" progress,
  AI-generated one-line summary of contents (or animated "···" while generating), plus a warning
  treatment if the section has overdue pending items.
- **Expanded**: header + "+ Add item" link + content:
  - A row of pills for non-deadline items (small calendar icon), followed by a separate row for
    recurring-item pills (infinity icon) when both exist
  - Full-width rows for deadline items
  - Full-width rows for calendar events (selected date only)
  - Full-width rows for reminders (selected date only)
  - "Nothing scheduled" placeholder text if the section is empty
- Tapping the header toggles collapsed/expanded with a spring animation. Sections auto-expand to
  the current time-of-day section on first load (today only); when a filter is active, sections
  with matching content auto-expand and empty ones auto-collapse (user can still override
  manually afterward).
- Cards are drop targets for drag-and-drop item reassignment.

### Open (any-time) card
- No border/background distinct from section cards' container style, sits below all section
  cards, scrolls with the page.
- Same pill layout for untimed items plus any-time reminders; "+ Add item" link; also a drop
  target.
- Overdue deadline items do not currently surface in this card or receive a missed-state visual.

### Progress ring
- Small 26×26 ring per section (in its header) and one larger one in the page-level progress row;
  fill color sweeps red → yellow → green as completion ratio increases; green + "All done!" text
  when 100%.

## Tab 2: Routine (or a name related to regular airplane maintenance)

Manages recurring habit templates. Infinity icon.

### Layout
- Non-swiping, single scrolling list of "schedule cards" — one each for the three fixed weekday
  patterns (Every Day, Weekdays, Weekends) plus any user-created custom weekday patterns, in that
  order.
- Toolbar: search toggle, filter button. Title "Routine."
- Floating circular "+" button (bottom-trailing) opens a weekday picker sheet to create a new
  custom schedule card (weekday pattern); duplicate patterns aren't offered.

### Schedule cards
- Rounded-rect card matching Day tab's section-card style.
- **Expanded header**: pattern name (e.g. "Weekdays"), "+" button (add a routine to this
  pattern), trash icon (custom patterns only — deleting prompts a confirmation dialog warning
  that past completions are kept as standalone items).
- **Collapsed header**: pattern name + routine count ("No routines" / "`N` routines").
- Expanded body contains one **segment card** per day-section (plus "Open"), always rendered even
  when empty, so every segment has its own drop target and "+ Add item" affordance.
- Cards are drop targets: dragging a routine pill onto a different schedule card reassigns its
  weekday pattern.

### Segment cards (nested inside each schedule card)
- Smaller rounded-rect card (14pt radius) per day section, styled like a mini version of the Day
  tab's section card.
- **Header**: segment name + time range, item-count badge; when collapsed, shows either "No
  routines," an AI-generated one-line summary, animated loading dots, or a deterministic
  fallback summary (joined title/time list, "+N more") if AI is unavailable.
- **Expanded body**: full-width rows for timed routines (clock time + title + flag/notes icons),
  then a pill flow for untimed routines; "+ Add item" link pre-filled with this pattern + segment.
- Routine pills/rows: tap to edit; long-press for Edit/Delete; drag to move between segments
  (reassigns day section) or onto a different schedule card (reassigns weekday pattern); dropping
  highlights the target segment with an accent border.

## Tab 3: Timeline (or "Nav Log")

A chronological, multi-day, fully-interactive log. Checklist icon.

### Layout
- Standard `List` (inset-grouped), grouped into date sections, sorted chronologically.
- Starting window is ±7 days from today; scrolling to the first/last loaded day silently extends
  the window another 7 days in that direction (infinite scroll illusion). Initial scroll position
  centers on today.
- Toolbar: "Go to Today" (scope icon, scrolls list back to today's section), search toggle, filter
  button.
- Today's date-header row: red dot + "TODAY" (red, bold) + short date. Other rows: weekday + date,
  dimmed if in the past.
- Each date section is itself broken into the same day-section sub-groups as the Day tab (segment
  header row showing the section name + a "+" add-to-that-segment button), each followed by its
  item rows.
- Past days only show sections that actually have items (no empty placeholders); today and future
  days always show every segment (even empty) so there's always an "Add item" entry point.
- Future dates never show materialized recurring instances (only real one-off items) since a
  routine could still change before then.

### Row content
- Compact single-line-title row: checkbox, title (strikethrough if done/canceled, red flag icon
  if flagged, note icon if notes present), and a subtitle line showing date (search results only)
  and/or deadline time.
- Tap row → edit sheet. Tap checkbox → toggle pending/completed. Long-press → Edit / Cancel
  context menu. (No swipe-to-defer gesture here, unlike the Day tab.)

### Search
- Typing a query switches the whole list to a flat, date-free `ContentUnavailableView.search`-
  backed results list (title/notes match, server-side fetch across *all* time, not just the
  loaded window) — each result row shows its date inline. Clearing search returns to the grouped
  view.

## Shared sheet: Markdown/text import

Opened from the Day tab's "Import" toolbar button (arrow-down-doc icon).

- **Paste step**: a plain multi-line text editor (monospaced), auto-prepopulated from the system
  clipboard on open. An info button opens a "How it works" help sheet explaining the flow. "Review"
  button (disabled while empty) triggers on-device AI parsing with a full-screen "Analyzing…"
  overlay.
- **Parsing**: Apple Intelligence (Foundation Models) extracts one task per line, stripping
  checkbox/bullet/date-prefix syntax, guessing a day section from content, and flagging likely
  recurring habits with a suggested weekday schedule. Falls back to a plain regex strip (every
  line becomes an untouched one-off "Open" item) if the on-device model isn't available.
- **Review step**: an editable list — each row has an inline title text field, a segment-picker
  menu capsule, a "Routine" toggle capsule (shows a weekday-pattern label like "Weekdays" or
  "3×/wk" once enabled, revealing the 7-day picker circles), and a delete (×) button.
  Swipe-to-delete also works. A "← Back to text" footer link returns to the paste step without
  losing the original text. The toolbar's primary action shows "Add `N`" and commits all
  surviving rows as real items/templates for the day the import was opened from.
