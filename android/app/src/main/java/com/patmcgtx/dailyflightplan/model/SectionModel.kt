package com.patmcgtx.dailyflightplan.model

/** Everything a section card needs to draw itself, computed once from the day's items. */
data class SectionModel(
    val section: DaySection,
    /** Untimed items assigned to this section. */
    val pills: List<PlanItem>,
    /**
     * Timed items whose clock time falls in this section. Unlike the iOS Cockpit, a pending item
     * whose time has passed stays here (drawn as missed) instead of disappearing.
     */
    val deadlines: List<PlanItem>,
    /** Ids of [deadlines] that are pending with a time that has already passed today. */
    val missedItemIds: Set<Long>,
    /** Done/total over every non-canceled item in the section, regardless of the status filter. */
    val progress: Progress,
    val isCurrent: Boolean,
    /** The section's window has passed but it still has pending items. */
    val hasOverdue: Boolean,
    /** At least one pending item is flagged. */
    val hasFlaggedPending: Boolean,
) {
    val hasContent: Boolean get() = pills.isNotEmpty() || deadlines.isNotEmpty()
}

/** What a screen reader says for a section card header, e.g. "Morning, 7:30 – 11 AM, current section, 2 of 3 done, overdue". */
fun SectionModel.accessibilitySummary(): String = buildList {
    add(section.displayName)
    add(section.timeRangeLabel)
    if (isCurrent) add("current section")
    add(progress.spokenStatus())
    if (hasOverdue) add("overdue")
    if (hasFlaggedPending) add("has flagged items")
}.joinToString(", ")

/** "nothing scheduled", "all 3 done", or "2 of 3 done". */
fun Progress.spokenStatus(): String = when {
    total == 0 -> "nothing scheduled"
    isAllDone -> "all $total done"
    else -> "$completed of $total done"
}

/**
 * What a screen reader should add to an item's name, since color and strikethrough don't carry
 * over: "Flagged", "Completed", "Missed", combined with commas; null for a plain pending item.
 */
fun PlanItem.accessibilityState(isMissed: Boolean = false): String? = buildList {
    when (status) {
        ItemStatus.Completed -> add("Completed")
        ItemStatus.Canceled -> add("Canceled")
        ItemStatus.Pending -> Unit
    }
    if (isFlagged) add("Flagged")
    if (isMissed) add("Missed")
}.takeIf { it.isNotEmpty() }?.joinToString(", ")

/**
 * Builds the [SectionModel] for [section]. [visible] is what the status filter lets through (it
 * decides what's drawn); [raw] is every non-canceled item (it decides the counts), matching the
 * iOS Cockpit.
 */
fun DayContext.sectionModel(
    section: DaySection,
    visible: List<PlanItem>,
    raw: List<PlanItem>,
): SectionModel {
    val rawInSection = sectionPills(section, raw) + timedRows(section, raw)
    val deadlines = timedRows(section, visible)
    return SectionModel(
        section = section,
        pills = sectionPills(section, visible),
        deadlines = deadlines,
        missedItemIds = deadlines.filter(::isDeadlineMissed).map { it.id }.toSet(),
        progress = Progress.of(rawInSection),
        isCurrent = currentSection == section,
        hasOverdue = hasOverdue(section, rawInSection),
        hasFlaggedPending = rawInSection.any { it.isFlagged && it.status == ItemStatus.Pending },
    )
}
