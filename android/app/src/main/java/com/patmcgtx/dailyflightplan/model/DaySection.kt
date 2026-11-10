package com.patmcgtx.dailyflightplan.model

import java.time.LocalTime

/**
 * The six time-of-day sections that organize the day. Declared in chronological order, so
 * [entries] is the order sections appear on screen. Ported from the iOS `DaySection.swift`; the
 * minute ranges and labels must stay in sync with it.
 */
enum class DaySection(
    val displayName: String,
    /** Minutes since midnight at which this section begins. */
    val startMinutes: Int,
    /** Minutes since midnight at which this section ends (inclusive). */
    val endMinutes: Int,
    /** Human-readable time range shown in section headers. */
    val timeRangeLabel: String,
) {
    FirstThing("First Thing", 0, 7 * 60 + 29, "before 7:30 AM"),
    Morning("Morning", 7 * 60 + 30, 10 * 60 + 59, "7:30 – 11 AM"),
    Midday("Midday", 11 * 60, 12 * 60 + 59, "11 AM – 1 PM"),
    Afternoon("Afternoon", 13 * 60, 16 * 60 + 59, "1 – 5 PM"),
    Evening("Evening", 17 * 60, 21 * 60 + 59, "5 – 10 PM"),
    Bedtime("Bedtime", 22 * 60, 23 * 60 + 59, "10 PM – midnight");

    /** Earliest hour (24h), derived from [startMinutes]. */
    val startHour: Int get() = startMinutes / 60

    /** Last hour (24h) inclusive, derived from [endMinutes]. */
    val endHour: Int get() = endMinutes / 60

    companion object {
        /** The section that contains [time] (seconds are ignored), or null if none match. */
        fun containing(time: LocalTime): DaySection? {
            val minutes = time.hour * 60 + time.minute
            return entries.firstOrNull { minutes in it.startMinutes..it.endMinutes }
        }
    }
}
