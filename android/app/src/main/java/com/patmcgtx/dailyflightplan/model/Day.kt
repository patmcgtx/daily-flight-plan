package com.patmcgtx.dailyflightplan.model

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.time.LocalDate

/**
 * Per-calendar-day details the user can customize: the day's flight name and its intention
 * ("destination"). Rows are created lazily on first edit, so most days have no [Day] at all.
 * Items match a day by date, not by a relationship. [date] is the primary key, so unlike iOS
 * there's no duplicate-row cleanup. Also the Room entity for the `days` table.
 */
@Entity(tableName = "days")
data class Day(
    @PrimaryKey val date: LocalDate,
    /** The user's custom flight name. Empty means "use the default `DFP YYYYMMDD` number". */
    val flightName: String = "",
    /** The day's intention note. Empty means none has been written. */
    val intention: String = "",
) {

    /** A copy with [name] as the flight name, capped at [MAX_FLIGHT_NAME_LENGTH] characters. */
    fun withFlightName(name: String): Day = copy(flightName = name.takeCodePoints(MAX_FLIGHT_NAME_LENGTH))

    fun withIntention(text: String): Day = copy(intention = text)

    /** True when the user hasn't customized anything on this day. */
    val isBlank: Boolean get() = flightName.isBlank() && intention.isBlank()

    /** The flight name to display: the user's entry if it isn't blank, else the default number. */
    val displayFlightNumber: String
        get() = flightName.trim().ifEmpty { defaultFlightNumber(date) }

    companion object {
        const val MAX_FLIGHT_NAME_LENGTH = 24

        /** The auto-generated mock flight number: "DFP" plus the date as YYYYMMDD. */
        fun defaultFlightNumber(date: LocalDate): String =
            "DFP %04d%02d%02d".format(date.year, date.monthValue, date.dayOfMonth)
    }
}

/** Takes at most [count] Unicode code points, so a surrogate pair (e.g. an emoji) is never split. */
private fun String.takeCodePoints(count: Int): String =
    if (codePointCount(0, length) <= count) this else substring(0, offsetByCodePoints(0, count))
