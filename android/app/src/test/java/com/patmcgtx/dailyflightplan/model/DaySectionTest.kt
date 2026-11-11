package com.patmcgtx.dailyflightplan.model

import java.time.LocalTime
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource
import org.junit.jupiter.api.Test

/** Ported from the iOS `DaySectionTests`; section times come from `DaySection.swift`. */
class DaySectionTest {

    @Test
    fun `Sections are ordered chronologically through the day`() {
        val starts = DaySection.entries.map { it.startMinutes }
        assertEquals(starts.sorted(), starts)
    }

    @Test
    fun `Sections tile the whole day with no gaps or overlaps`() {
        assertEquals(0, DaySection.entries.first().startMinutes)
        assertEquals(24 * 60 - 1, DaySection.entries.last().endMinutes)
        DaySection.entries.zipWithNext().forEach { (earlier, later) ->
            assertEquals(earlier.endMinutes + 1, later.startMinutes, "${earlier.name} to ${later.name}")
        }
    }

    @ParameterizedTest(name = "{0} is displayed as {1}")
    @MethodSource("displayNames")
    fun `Display name matches the expected human-readable section name`(section: DaySection, expected: String) {
        assertEquals(expected, section.displayName)
    }

    @ParameterizedTest(name = "{0} shows the range {1}")
    @MethodSource("timeRangeLabels")
    fun `Time range label matches the expected displayed range`(section: DaySection, expected: String) {
        assertEquals(expected, section.timeRangeLabel)
    }

    @ParameterizedTest(name = "{0} spans hours {1} to {2}")
    @MethodSource("hourBoundaries")
    fun `Start and end hour are derived correctly from the section's minute range`(
        section: DaySection,
        expectedStartHour: Int,
        expectedEndHour: Int,
    ) {
        assertEquals(expectedStartHour, section.startHour)
        assertEquals(expectedEndHour, section.endHour)
    }

    /** Each pair marks a section's first and last minute, so both edges and the handoff are covered. */
    @ParameterizedTest(name = "{0}:{1} is in {2}")
    @MethodSource("boundaryMinutes")
    fun `Containing resolves the correct section at each boundary minute`(
        hour: Int,
        minute: Int,
        expected: DaySection,
    ) {
        assertEquals(expected, DaySection.containing(LocalTime.of(hour, minute)))
    }

    @Test
    fun `Containing ignores seconds so the last second of a section still belongs to it`() {
        assertEquals(DaySection.FirstThing, DaySection.containing(LocalTime.of(7, 29, 59)))
        assertEquals(DaySection.Bedtime, DaySection.containing(LocalTime.MAX))
    }

    @Test
    fun `Every minute of the day resolves to exactly one section`() {
        for (minute in 0 until 24 * 60) {
            val time = LocalTime.of(minute / 60, minute % 60)
            val matches = DaySection.entries.filter { minute in it.startMinutes..it.endMinutes }
            assertEquals(1, matches.size, "minute $minute")
            assertTrue(DaySection.containing(time) == matches.single())
        }
    }

    companion object {
        @JvmStatic
        fun displayNames(): Stream<Arguments> = Stream.of(
            arguments(DaySection.FirstThing, "First Thing"),
            arguments(DaySection.Morning, "Morning"),
            arguments(DaySection.Midday, "Midday"),
            arguments(DaySection.Afternoon, "Afternoon"),
            arguments(DaySection.Evening, "Evening"),
            arguments(DaySection.Bedtime, "Bedtime"),
        )

        @JvmStatic
        fun timeRangeLabels(): Stream<Arguments> = Stream.of(
            arguments(DaySection.FirstThing, "before 7:30 AM"),
            arguments(DaySection.Morning, "7:30 – 11 AM"),
            arguments(DaySection.Midday, "11 AM – 1 PM"),
            arguments(DaySection.Afternoon, "1 – 5 PM"),
            arguments(DaySection.Evening, "5 – 10 PM"),
            arguments(DaySection.Bedtime, "10 PM – midnight"),
        )

        @JvmStatic
        fun hourBoundaries(): Stream<Arguments> = Stream.of(
            arguments(DaySection.FirstThing, 0, 7),
            arguments(DaySection.Morning, 7, 10),
            arguments(DaySection.Midday, 11, 12),
            arguments(DaySection.Afternoon, 13, 16),
            arguments(DaySection.Evening, 17, 21),
            arguments(DaySection.Bedtime, 22, 23),
        )

        @JvmStatic
        fun boundaryMinutes(): Stream<Arguments> = Stream.of(
            arguments(0, 0, DaySection.FirstThing),
            arguments(7, 29, DaySection.FirstThing),
            arguments(7, 30, DaySection.Morning),
            arguments(10, 59, DaySection.Morning),
            arguments(11, 0, DaySection.Midday),
            arguments(12, 59, DaySection.Midday),
            arguments(13, 0, DaySection.Afternoon),
            arguments(16, 59, DaySection.Afternoon),
            arguments(17, 0, DaySection.Evening),
            arguments(21, 59, DaySection.Evening),
            arguments(22, 0, DaySection.Bedtime),
            arguments(23, 59, DaySection.Bedtime),
        )
    }
}
