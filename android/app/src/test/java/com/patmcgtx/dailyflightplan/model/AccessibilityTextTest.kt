package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

/** The sentences a screen reader speaks for color-only and symbol-only cues. */
class AccessibilityTextTest {

    private val date = LocalDate.of(2026, 6, 15)

    private fun model(
        progress: Progress,
        isCurrent: Boolean = false,
        hasOverdue: Boolean = false,
        hasFlaggedPending: Boolean = false,
    ) = SectionModel(
        section = DaySection.Morning,
        pills = emptyList(),
        deadlines = emptyList(),
        missedItemIds = emptySet(),
        progress = progress,
        isCurrent = isCurrent,
        hasOverdue = hasOverdue,
        hasFlaggedPending = hasFlaggedPending,
    )

    @ParameterizedTest(name = "{0} of {1} done is spoken as {2}")
    @MethodSource("spokenStatuses")
    fun `spokenStatus describes progress in words`(completed: Int, total: Int, expected: String) {
        assertEquals(expected, Progress(completed, total).spokenStatus())
    }

    @Test
    fun `A plain section card is spoken as name, range, and progress`() {
        assertEquals("Morning, 7:30 – 11 AM, 2 of 3 done", model(Progress(2, 3)).accessibilitySummary())
    }

    @Test
    fun `A section card adds current, overdue and flagged cues in order`() {
        val summary = model(Progress(0, 2), isCurrent = true, hasOverdue = true, hasFlaggedPending = true).accessibilitySummary()
        assertEquals("Morning, 7:30 – 11 AM, current section, 0 of 2 done, overdue, has flagged items", summary)
    }

    @Test
    fun `An empty or finished section card says so`() {
        assertEquals("Morning, 7:30 – 11 AM, nothing scheduled", model(Progress(0, 0)).accessibilitySummary())
        assertEquals("Morning, 7:30 – 11 AM, all 4 done", model(Progress(4, 4)).accessibilitySummary())
    }

    @ParameterizedTest(name = "{0}, flagged {1}, missed {2} is spoken as {3}")
    @MethodSource("itemStates")
    fun `accessibilityState names the status, flag and missed cues that color alone would carry`(
        status: ItemStatus,
        flagged: Boolean,
        missed: Boolean,
        expected: String?,
    ) {
        val item = PlanItem(title = "Item", date = date, status = status, isFlagged = flagged)
        if (expected == null) assertNull(item.accessibilityState(missed)) else assertEquals(expected, item.accessibilityState(missed))
    }

    @Test
    fun `dayDescription appends how the day relates to today`() {
        val formatter = DateTimeFormatter.ofPattern("EEEE, MMMM d", Locale.US)
        assertEquals("Monday, June 15, today", Briefing.dayDescription(date, RelativeDay.Today, formatter))
        assertEquals("Monday, June 15, tomorrow", Briefing.dayDescription(date, RelativeDay.Tomorrow, formatter))
        assertEquals("Monday, June 15, yesterday", Briefing.dayDescription(date, RelativeDay.Yesterday, formatter))
        assertEquals("Monday, June 15", Briefing.dayDescription(date, null, formatter))
    }

    companion object {
        @JvmStatic
        fun spokenStatuses(): Stream<Arguments> = Stream.of(
            arguments(0, 0, "nothing scheduled"),
            arguments(0, 3, "0 of 3 done"),
            arguments(2, 3, "2 of 3 done"),
            arguments(3, 3, "all 3 done"),
        )

        @JvmStatic
        fun itemStates(): Stream<Arguments> = Stream.of(
            arguments(ItemStatus.Pending, false, false, null),
            arguments(ItemStatus.Pending, true, false, "Flagged"),
            arguments(ItemStatus.Pending, false, true, "Missed"),
            arguments(ItemStatus.Pending, true, true, "Flagged, Missed"),
            arguments(ItemStatus.Completed, false, false, "Completed"),
            arguments(ItemStatus.Completed, true, false, "Completed, Flagged"),
            arguments(ItemStatus.Canceled, false, false, "Canceled"),
        )
    }
}
