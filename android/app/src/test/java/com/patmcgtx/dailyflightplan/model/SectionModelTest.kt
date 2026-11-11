package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

/** Covers `DayContext.relativeDay`/`hasOverdue` and the `sectionModel` builder the section cards draw from. */
class SectionModelTest {

    private val today = LocalDate.of(2026, 6, 15)
    private var nextId = 1L

    private fun context(selected: LocalDate = today, hour: Int = 12, minute: Int = 0) =
        DayContext(selected, LocalDateTime.of(today, LocalTime.of(hour, minute)))

    private fun item(
        section: DaySection? = null,
        deadline: LocalTime? = null,
        status: ItemStatus = ItemStatus.Pending,
        flagged: Boolean = false,
    ) = PlanItem(id = nextId++, title = "Item", isFlagged = flagged, date = today, deadline = deadline, daySection = section, status = status)

    // region relativeDay

    @ParameterizedTest(name = "{0} days from today is {1}")
    @MethodSource("relativeDays")
    fun `relativeDay names yesterday, today and tomorrow and nothing else`(offset: Long, expected: RelativeDay?) {
        assertEquals(expected, context(selected = today.plusDays(offset)).relativeDay)
    }

    // endregion

    // region hasOverdue

    @ParameterizedTest(name = "{0} at {1}:{2} with a pending item is overdue = {3}")
    @MethodSource("overdueTimes")
    fun `hasOverdue is true once a section's window has passed while it still has pending items`(
        section: DaySection,
        hour: Int,
        minute: Int,
        expected: Boolean,
    ) {
        assertEquals(expected, context(hour = hour, minute = minute).hasOverdue(section, listOf(item(section))))
    }

    @Test
    fun `hasOverdue is false when everything in the passed section is done or there is nothing in it`() {
        val context = context(hour = 20)
        assertFalse(context.hasOverdue(DaySection.Morning, listOf(item(DaySection.Morning, status = ItemStatus.Completed))))
        assertFalse(context.hasOverdue(DaySection.Morning, emptyList()))
    }

    @Test
    fun `hasOverdue is never true on another day`() {
        val tomorrow = context(selected = today.plusDays(1), hour = 20)
        assertFalse(tomorrow.hasOverdue(DaySection.Morning, listOf(item(DaySection.Morning))))
    }

    // endregion

    // region sectionModel

    @Test
    fun `sectionModel splits a section's items into untimed pills and timed rows`() {
        val pill = item(section = DaySection.Evening)
        val row = item(deadline = LocalTime.of(18, 0))
        val elsewhere = item(section = DaySection.Morning)
        val model = context(hour = 9).sectionModel(DaySection.Evening, listOf(pill, row, elsewhere), listOf(pill, row, elsewhere))

        assertEquals(listOf(pill), model.pills)
        assertEquals(listOf(row), model.deadlines)
        assertTrue(model.hasContent)
    }

    @Test
    fun `sectionModel counts progress over every non-canceled item even when the filter hides completed ones`() {
        val done = item(section = DaySection.Evening, status = ItemStatus.Completed)
        val pending = item(section = DaySection.Evening)
        val raw = listOf(done, pending)
        val visible = raw.matchingStatusFilter(showCompleted = false)
        val model = context(hour = 9).sectionModel(DaySection.Evening, visible, raw)

        assertEquals(listOf(pending), model.pills)
        assertEquals(Progress(1, 2), model.progress)
    }

    @Test
    fun `sectionModel has no content but still reports done when every item is completed and hidden`() {
        val done = item(section = DaySection.Evening, status = ItemStatus.Completed)
        val model = context(hour = 9).sectionModel(DaySection.Evening, emptyList(), listOf(done))

        assertFalse(model.hasContent)
        assertTrue(model.progress.isAllDone)
    }

    @Test
    fun `sectionModel marks only the section containing now as current and only on today`() {
        assertTrue(context(hour = 12).sectionModel(DaySection.Midday, emptyList(), emptyList()).isCurrent)
        assertFalse(context(hour = 12).sectionModel(DaySection.Morning, emptyList(), emptyList()).isCurrent)
        assertFalse(context(selected = today.plusDays(1), hour = 12).sectionModel(DaySection.Midday, emptyList(), emptyList()).isCurrent)
    }

    @ParameterizedTest(name = "flagged {0}, status {1}: highlight = {2}")
    @MethodSource("flaggedCases")
    fun `sectionModel highlights a section only for flagged items that are still pending`(
        flagged: Boolean,
        status: ItemStatus,
        expected: Boolean,
    ) {
        val subject = item(section = DaySection.Evening, status = status, flagged = flagged)
        val model = context(hour = 9).sectionModel(DaySection.Evening, listOf(subject), listOf(subject))
        assertEquals(expected, model.hasFlaggedPending)
    }

    @Test
    fun `sectionModel keeps a timed item whose deadline was missed, counted as still pending`() {
        val missed = item(deadline = LocalTime.of(8, 0))
        val model = context(hour = 12).sectionModel(DaySection.Morning, listOf(missed), listOf(missed))

        assertEquals(listOf(missed), model.deadlines)
        assertEquals(Progress(0, 1), model.progress)
        assertTrue(model.hasOverdue)
        assertEquals(setOf(missed.id), model.missedItemIds)
    }

    @Test
    fun `Upcoming and completed timed items are not marked missed`() {
        val upcoming = item(deadline = LocalTime.of(10, 0))
        val doneEarlier = item(deadline = LocalTime.of(8, 0), status = ItemStatus.Completed)
        val model = context(hour = 9).sectionModel(DaySection.Morning, listOf(upcoming, doneEarlier), listOf(upcoming, doneEarlier))
        assertEquals(emptySet<Long>(), model.missedItemIds)
    }

    @Test
    fun `timedRows lists timed items in a section earliest first, missed or not, and deadlineRows drops the missed ones`() {
        val missed = item(deadline = LocalTime.of(8, 0))
        val upcoming = item(deadline = LocalTime.of(10, 0))
        val context = context(hour = 9)
        assertEquals(listOf(missed.id, upcoming.id), context.timedRows(DaySection.Morning, listOf(upcoming, missed)).map { it.id })
        assertEquals(listOf(upcoming.id), context.deadlineRows(DaySection.Morning, listOf(upcoming, missed)).map { it.id })
    }

    @Test
    fun `sectionModel flags a past section with pending items as overdue`() {
        val pending = item(section = DaySection.Morning)
        assertTrue(context(hour = 14).sectionModel(DaySection.Morning, listOf(pending), listOf(pending)).hasOverdue)
        assertFalse(context(hour = 9).sectionModel(DaySection.Morning, listOf(pending), listOf(pending)).hasOverdue)
    }

    // endregion

    companion object {
        @JvmStatic
        fun relativeDays(): Stream<Arguments> = Stream.of(
            arguments(-2L, null),
            arguments(-1L, RelativeDay.Yesterday),
            arguments(0L, RelativeDay.Today),
            arguments(1L, RelativeDay.Tomorrow),
            arguments(2L, null),
        )

        @JvmStatic
        fun overdueTimes(): Stream<Arguments> = Stream.of(
            arguments(DaySection.FirstThing, 7, 29, false),
            arguments(DaySection.FirstThing, 7, 30, true),
            arguments(DaySection.Morning, 10, 59, false),
            arguments(DaySection.Morning, 11, 0, true),
            arguments(DaySection.Bedtime, 23, 59, false),
        )

        @JvmStatic
        fun flaggedCases(): Stream<Arguments> = Stream.of(
            arguments(true, ItemStatus.Pending, true),
            arguments(false, ItemStatus.Pending, false),
            arguments(true, ItemStatus.Completed, false),
        )
    }
}
