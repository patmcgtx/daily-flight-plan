package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * The pure, clock-dependent logic behind a day's screen — the Android counterpart of the
 * non-UI parts of the iOS `DayViewModel`. It holds no state and does no I/O: callers pass the
 * [selectedDate] being viewed and the current [now], so everything is deterministic to test.
 * The Cockpit view model (plan phase 4) wraps this and supplies a live clock.
 */
class DayContext(
    val selectedDate: LocalDate,
    val now: LocalDateTime,
) {

    val isToday: Boolean get() = selectedDate == now.toLocalDate()

    /** The section containing the current clock time, or null when not viewing today. */
    val currentSection: DaySection?
        get() = if (isToday) DaySection.containing(now.toLocalTime()) else null

    /** Sections whose window has already ended while viewing today. Empty on other days. */
    val pastSections: List<DaySection>
        get() {
            val current = currentSection ?: return emptyList()
            return DaySection.entries.takeWhile { it != current }
        }

    /**
     * True only for pending items with a specific clock time that has now passed, while viewing
     * today. Section-assigned items without a deadline stay in their section regardless of time.
     */
    fun isDeadlineMissed(item: PlanItem): Boolean {
        val deadline = item.deadline ?: return false
        return isToday && item.status == ItemStatus.Pending && deadline.isBefore(now.toLocalTime())
    }

    /** Items assigned to [section], excluding those whose deadline has been missed. */
    fun sectionPills(section: DaySection, items: List<PlanItem>): List<PlanItem> =
        items.filter { it.daySection == section && !isDeadlineMissed(it) }

    /**
     * Unsectioned items whose deadline falls within [section] (excluding missed ones), earliest
     * first.
     */
    fun deadlineRows(section: DaySection, items: List<PlanItem>): List<PlanItem> =
        items
            .filter { item ->
                val deadline = item.deadline
                deadline != null && item.daySection == null && !isDeadlineMissed(item) &&
                    DaySection.containing(deadline) == section
            }
            .sortedBy { it.deadline }

    /** Pending items whose specific deadline has passed, earliest first. */
    fun missedDeadlineItems(items: List<PlanItem>): List<PlanItem> =
        items.filter(::isDeadlineMissed).sortedBy { it.deadline }

    /** Truly untimed items: no section assignment and no deadline. */
    fun anyTimeItems(items: List<PlanItem>): List<PlanItem> =
        items.filter { it.daySection == null && it.deadline == null }

    /**
     * The earliest upcoming deadline among pending [items] — preferring ones still ahead of [now]
     * when viewing today, falling back to the day's earliest deadline otherwise (a past or future
     * day, or a today whose remaining deadlines have all slipped by).
     */
    fun nextUpcomingDeadline(items: List<PlanItem>): LocalTime? {
        val pending = items.mapNotNull { item ->
            item.deadline.takeIf { item.status == ItemStatus.Pending }
        }
        if (pending.isEmpty()) return null
        val upcoming = if (isToday) pending.filter { !it.isBefore(now.toLocalTime()) } else pending
        return (upcoming.ifEmpty { pending }).min()
    }

    /** Count of pending items flagged as a priority. */
    fun outstandingFlaggedCount(items: List<PlanItem>): Int =
        items.count { it.isFlagged && it.status == ItemStatus.Pending }
}
