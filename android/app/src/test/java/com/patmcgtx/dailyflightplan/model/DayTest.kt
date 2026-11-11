package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

/** Ported from the iOS `DayTests` (minus the SwiftData persistence and date-normalizing cases). */
class DayTest {

    private val june15 = LocalDate.of(2026, 6, 15)

    @ParameterizedTest(name = "entering \"{0}\" displays \"{1}\"")
    @MethodSource("flightNames")
    fun `displayFlightNumber falls back to DFP plus YYYYMMDD until a non-blank name is set`(
        entered: String,
        expected: String,
    ) {
        assertEquals(expected, Day(june15).withFlightName(entered).displayFlightNumber)
    }

    @ParameterizedTest(name = "{0} gets the default number {1}")
    @MethodSource("defaultNumbers")
    fun `The default flight number is DFP plus the zero-padded date`(date: LocalDate, expected: String) {
        assertEquals(expected, Day.defaultFlightNumber(date))
    }

    @Test
    fun `withFlightName caps the name at the maximum length`() {
        val day = Day(june15).withFlightName("A".repeat(100))
        assertEquals(Day.MAX_FLIGHT_NAME_LENGTH, day.flightName.length)
    }

    @Test
    fun `withFlightName never splits an emoji when capping`() {
        val day = Day(june15).withFlightName("😀".repeat(30))
        assertEquals("😀".repeat(Day.MAX_FLIGHT_NAME_LENGTH), day.flightName)
    }

    @Test
    fun `withFlightName leaves a name at or under the limit untouched`() {
        val name = "B".repeat(Day.MAX_FLIGHT_NAME_LENGTH)
        assertEquals(name, Day(june15).withFlightName(name).flightName)
    }

    @ParameterizedTest(name = "flight \"{0}\" and intention \"{1}\" blank = {2}")
    @MethodSource("blankness")
    fun `isBlank reflects whether anything is customized`(flight: String, intention: String, expectedBlank: Boolean) {
        val day = Day(june15).withFlightName(flight).withIntention(intention)
        assertEquals(expectedBlank, day.isBlank)
    }

    @Test
    fun `Setters return a modified copy and leave the original untouched`() {
        val original = Day(june15)
        val edited = original.withFlightName("Deep Work").withIntention("Ship the release")
        assertEquals(Day(june15), original)
        assertEquals(Day(june15, "Deep Work", "Ship the release"), edited)
    }

    companion object {
        @JvmStatic
        fun flightNames(): Stream<Arguments> = Stream.of(
            arguments("", "DFP 20260615"),
            arguments("   ", "DFP 20260615"),
            arguments("Deep Work", "Deep Work"),
            arguments("  Deep Work  ", "Deep Work"),
        )

        @JvmStatic
        fun defaultNumbers(): Stream<Arguments> = Stream.of(
            arguments(LocalDate.of(2026, 6, 15), "DFP 20260615"),
            arguments(LocalDate.of(2026, 1, 5), "DFP 20260105"),
            arguments(LocalDate.of(2026, 12, 31), "DFP 20261231"),
        )

        @JvmStatic
        fun blankness(): Stream<Arguments> = Stream.of(
            arguments("", "", true),
            arguments("  ", "\n", true),
            arguments("Deep Work", "", false),
            arguments("", "Ship it", false),
        )
    }
}
