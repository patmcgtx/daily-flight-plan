package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

class BriefingTest {

    private val utc = ZoneId.of("UTC")

    private fun at(zone: ZoneId, y: Int, mo: Int, d: Int, h: Int, mi: Int, s: Int = 0) =
        ZonedDateTime.of(LocalDateTime.of(y, mo, d, h, mi, s), zone)

    @ParameterizedTest(name = "{0} reads {1}")
    @MethodSource("remainingCases")
    fun `remainingLabel counts hours and minutes left until midnight`(now: ZonedDateTime, expected: String) {
        assertEquals(expected, Briefing.remainingLabel(now))
    }

    @Test
    fun `The last second of the day has zero time remaining`() {
        assertEquals("0h 0m remaining", Briefing.remainingLabel(at(utc, 2026, 6, 15, 23, 59, 59).plusNanos(500_000_000)))
    }

    @ParameterizedTest(name = "{0} priorities reads {1}")
    @MethodSource("priorityCases")
    fun `priorityLabel pluralizes correctly`(count: Int, expected: String) {
        assertEquals(expected, Briefing.priorityLabel(count))
    }

    @ParameterizedTest(name = "{0} viewed from {1}: {2}")
    @MethodSource("blurbCases")
    fun `dayBlurb distinguishes past days from future days`(date: LocalDate, today: LocalDate, expected: String) {
        assertEquals(expected, Briefing.dayBlurb(date, today))
    }

    companion object {
        @JvmStatic
        fun remainingCases(): Stream<Arguments> {
            val utc = ZoneId.of("UTC")
            val newYork = ZoneId.of("America/New_York")
            fun at(zone: ZoneId, y: Int, mo: Int, d: Int, h: Int, mi: Int) =
                ZonedDateTime.of(LocalDateTime.of(y, mo, d, h, mi), zone)
            return Stream.of(
                arguments(at(utc, 2026, 6, 15, 0, 0), "24h 0m remaining"),
                arguments(at(utc, 2026, 6, 15, 12, 0), "12h 0m remaining"),
                arguments(at(utc, 2026, 6, 15, 18, 45), "5h 15m remaining"),
                arguments(at(utc, 2026, 6, 15, 23, 59), "0h 1m remaining"),
                // Spring-forward day in New York is only 23 hours long.
                arguments(at(newYork, 2026, 3, 8, 0, 0), "23h 0m remaining"),
                // Fall-back day is 25 hours long.
                arguments(at(newYork, 2026, 11, 1, 0, 0), "25h 0m remaining"),
            )
        }

        @JvmStatic
        fun priorityCases(): Stream<Arguments> = Stream.of(
            arguments(0, "0 priorities"),
            arguments(1, "1 priority"),
            arguments(2, "2 priorities"),
            arguments(12, "12 priorities"),
        )

        @JvmStatic
        fun blurbCases(): Stream<Arguments> {
            val today = LocalDate.of(2026, 6, 15)
            return Stream.of(
                arguments(today.minusDays(1), today, "It's in the past"),
                arguments(today.minusDays(30), today, "It's in the past"),
                arguments(today.plusDays(1), today, "Future you"),
                arguments(today.plusDays(30), today, "Future you"),
            )
        }
    }
}
