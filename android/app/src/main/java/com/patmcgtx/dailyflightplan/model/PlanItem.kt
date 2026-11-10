package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.LocalTime

/**
 * A single task on the flight plan. v1 subset of the iOS `PlanItem`: no routines/templates,
 * categories, or reminder links (see `docs/android-port-plan.md`).
 */
data class PlanItem(
    val id: Long = 0,
    val title: String,
    val notes: String = "",
    val isFlagged: Boolean = false,
    /** The calendar day this item belongs to. */
    val date: LocalDate,
    /** A specific clock time. Null means the item is not time-specific. */
    val deadline: LocalTime? = null,
    /** The time-of-day section. Null when the item has a deadline or is explicitly "any time". */
    val daySection: DaySection? = null,
    val status: ItemStatus = ItemStatus.Pending,
)
