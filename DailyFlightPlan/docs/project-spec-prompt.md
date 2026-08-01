	Date:	July 30, 2026 at 6:49:04 PM CDT
	Weather:	97°F Clear
	Location:	Summer Moon Coffee, Austin, Texas, United States

# Daily Flight Planner app Figma UX mock and specs
This is rough, and the style is off, but hits all the bases. Woohoo! 

This is literally inspired by a real flight plan, low-level, plus my own experience with DayOne daily plans.

And no AI lol.

Here are the specs it brought out:

## Specs

### Technical specs
- Follow the architecture from my other app, [MapsPlus](https://github.com/patmcgtx/mapplus)
- Copy over the ARCHITECTURE.md from MapsPlus and modify here as we go
- Copy over MapsPlus themes and themes framework too
- Also copy over MapsPlus `CategoryCapsule` views, etc.
- Use SwiftData for persistence. We’ll want to add iCloud sync later but not yet.
- As we go, generate mock services and SwiftUI previews 
- Use [SwiftUI-Flow](https://github.com/tevelee/SwiftUI-Flow) for all flow views

### Feature specs
This is a daily planner app. It combines items added for to day specifically and recurring items. It’s based on an airplane flight plan checklist for inspiration, so today is a trip to a destination, and this is the checklist.

Let’s use SwiftUI and Liquid Glass for the UI.

#### Main “TODAY” view
The main view is a time-based view of today’s checklist.

##### Top area
At the top is today’s date with day of week and short date in the title. To the leading and trailing areas of this are buttons to go to yesterday for review and tomorrow for planning. Let’s add a placeholder button for a date selector too but not implement it yet.

This top area is sticky and does not scroll.

##### Day View
The main view does scroll vertically. It’s a view of today by time, similar to the day view in Apple’s Calendar app. The day view has calendar events and checklist items, some with specific time-based deadlines, some with more general deadlines per the “day sections” described below, and some with no time at all, aka “any time” items. Items will be described in more detail below.

The day view is broken into visible, **collapsible** “day sections” with a rounded-rect border and possibly a light background. The specific section times will be customizable later but we can hardcode for now.

- Morning (anything up to 10:59am)
- Midday (anything 11am to 12:59pm)
- Afternoon (1pm to 4:59pm)
- Evening (5pm to 7:59pm)
- Night (anything 8pm or later)

There is also an “any time” non-section section for items specially not associated with a time, sort of like the “all day” section of the Calendar app. The “any time” section should not have a border or background. This area should be at the bottom of the view but scroll with the rest of the sections.

### Items
The following kinds of items are displayed on the day view.

- **Calendar events** imported from the Calendar app. Tapping a calendar item links to the event in the Calendar app. Each calendar item has its own “line”, aka fills the view horizontally, and has a little calendar item.
- **A horizontal “now” bar** indicating the current time in the day
- ​**Deadline-based items**​: these items have specific time associated with time and a little “clock” icon. These items have a checkbox to indicate completion. Deadline-based items have their own “line” like calendar events. (We’ll want to add local notifications for these later.)
- ​**Day-section items**​: Items which are associated with a day section are displayed within that day section, at the top of it, in a horizontal flow layout. They have checkboxes too to indicate completion.
- ​**Any-time items**​: These items are similar to day-section items (horizontal flow) but are displayed in the “any time” non-section.
- All items (except calendar events) have an “info” icon to link to view its notes.

### Recurring items 
We also want a way to add recurring items. These are items that appear automatically every day. They are internally flagged as recurring and visually indicated as such with a small “infinity” icon.

### Creating items
Floating at the bottom of the view is a prominent “add item” button, centered horizontally.  When tapped, you can add an item with the following information:
- Short title
- Notes
- An “flag” to indicate this item is important (off by default)
- Date (default to today) and optional deadline time
- Whether the item is recurring or not - and allow the user to pick which days of the week it recurs on.
- Zero or more categories (like we do for Landmarks in MapsPlus)
- We will want a way to add and edit categories like in MapsPlus)

### Item day-view behavior
On the day view, items have a “complete” checkbox. Let’s also give a quick gesture to:
- Cancel the item rather than complete it (long press menu or swipe it left)
- Defer the item to tomorrow (long press menu of swipe it right)
- The long-press menu also has an “edit” option  to edit the item.

### Day-view progression
The day view always scrolls to “now” in the timeline.

#### incomplete items
Any incomplete items (not completed, canceled, or deferred) from earlier in the day fall down to the “any time” section”. These “missed” items get a special visual treatment to indicate they’re behind schedule, such as an orange or red color. All items in this “any time” section are part of this non-section’s horizontal flow, even if they previously had a specific time deadline before. Calendar events are a separate idea and never considered completed or missed so do not ever fall down into the “any time” section.

#### filtering 
The day view can be filtered as follows. Ideally, each toggle is a button with on/off modes (not a toggle switch). And each toggle button is directly tappable from the day view, not buried in a menu.

All filtering prefs are saved to @AppStorage.

- **Show only flagged items** - if toggled on, show only flagged/important items and hide all others. Off by default.
- **Show completed items** - if toggled on, show completed and canceled items along with everything else. By default, do not show items once they are completed or canceled. 
- **Show recurring items** - If toggled on, show recurring items. If off show only non-recurring items. This one is *on* by default.

**Filter by categories** - let’s add a way to show selected categories like in MapsPlus. It might make sense to add a horizontal scroll view to select categories in one line? And/or this one could be a special button you tap to popup a category selector like in MapsPlus.

### Global day view items
On the main day view, we also want the following items presented ideally with one tap, similar to MapsPlus.

- ​**Progress indicator:**​ It would be really nice to have some simple visual progress indicator, maybe like a small exercise ring, of how the day’s going. Are you on track? Are you behind on a lot of stuff? Keep it light and friendly. I’m leaning towards an exercise ring or donut that fills up and had a “mood” color. Keep it simple and intuitive. This probably belong at the top somewhere.
- **Settings button** -  a buttons that brings up preferences, where we will later add things like customizing the times for day sections or even adding/removing/editing day sections. Just a placeholder for now, though.
- **Theme selector** - A menu to select the theme, like in MapsPlus.

