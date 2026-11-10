package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.LocalTime
import java.time.temporal.ChronoUnit

/**
 * The editable fields of the add/edit item form, plus the rules for turning them into a saved
 * [PlanItem]. Pure data, so the form's behavior is unit-tested without any UI. Ported from the
 * iOS `ItemFormViewModel`, minus routines and categories.
 */
data class ItemFormState(
    val title: String = "",
    val notes: String = "",
    val isFlagged: Boolean = false,
    val date: LocalDate,
    /** Whether the item has a specific clock time. If so, [deadline] is used and [daySection] is not. */
    val hasDeadline: Boolean = false,
    /** Remembered even while [hasDeadline] is off, so toggling it back on offers a sensible time. */
    val deadline: LocalTime,
    /** The section for an untimed item; null means "Open" (any time). */
    val daySection: DaySection? = null,
) {

    /** A title with something other than whitespace in it is required to save. */
    val isValid: Boolean get() = title.isNotBlank()

    /**
     * The item to store, or null when the form isn't [isValid]. With [existing], the result keeps
     * its id and status and only takes this form's fields; otherwise it is a new pending item.
     * A timed item has no section and its time is cut to the minute; an untimed item has no time.
     */
    fun toPlanItem(existing: PlanItem? = null): PlanItem? {
        val trimmedTitle = title.trim()
        if (trimmedTitle.isEmpty()) return null
        val base = existing ?: PlanItem(title = trimmedTitle, date = date)
        return base.copy(
            title = trimmedTitle,
            notes = notes,
            isFlagged = isFlagged,
            date = date,
            deadline = if (hasDeadline) deadline.truncatedTo(ChronoUnit.MINUTES) else null,
            daySection = if (hasDeadline) null else daySection,
        )
    }

    companion object {
        /** A blank form for [date], optionally preset to [section]. [defaultTime] seeds the time picker. */
        fun forNew(date: LocalDate, section: DaySection? = null, defaultTime: LocalTime): ItemFormState =
            ItemFormState(date = date, daySection = section, deadline = defaultTime)

        /** The form pre-filled from [item]; [defaultTime] seeds the time picker if it has no time. */
        fun from(item: PlanItem, defaultTime: LocalTime): ItemFormState = ItemFormState(
            title = item.title,
            notes = item.notes,
            isFlagged = item.isFlagged,
            date = item.date,
            hasDeadline = item.deadline != null,
            deadline = item.deadline ?: defaultTime,
            daySection = item.daySection,
        )
    }
}

/** Which form is open: a new item for a date (optionally in a section), or an existing item. */
sealed interface ItemFormTarget {
    data class New(val date: LocalDate, val section: DaySection? = null) : ItemFormTarget
    data class Edit(val item: PlanItem) : ItemFormTarget
}
