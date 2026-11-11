package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/** Text for the Cockpit's "briefing" strip. */
object Briefing {

    /** Real seconds left until the next local midnight (23 or 25 hours on a DST change day). */
    fun secondsUntilMidnight(now: ZonedDateTime): Long {
        val nextMidnight = now.toLocalDate().plusDays(1).atStartOfDay(now.zone)
        return maxOf(0L, ChronoUnit.SECONDS.between(now, nextMidnight))
    }

    /** e.g. "5h 12m remaining". */
    fun remainingLabel(now: ZonedDateTime): String {
        val seconds = secondsUntilMidnight(now)
        return "${seconds / 3600}h ${seconds % 3600 / 60}m remaining"
    }

    fun priorityLabel(count: Int): String = "$count ${if (count == 1) "priority" else "priorities"}"

    /** The day heading as spoken, e.g. "Monday, November 9, 2026, today". */
    fun dayDescription(date: LocalDate, relativeDay: RelativeDay?, formatter: DateTimeFormatter): String {
        val formatted = date.format(formatter)
        return if (relativeDay == null) formatted else "$formatted, ${relativeDay.name.lowercase()}"
    }

    /** Shown instead of the live clock on days other than today. */
    fun dayBlurb(date: LocalDate, today: LocalDate): String =
        if (date.isBefore(today)) "It's in the past" else "Future you"
}
