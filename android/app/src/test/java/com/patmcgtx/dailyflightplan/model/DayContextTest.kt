package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.EnumSource
import org.junit.jupiter.params.provider.MethodSource

/**
 * Ported from the iOS `DayViewModelTests`. Unlike the iOS suite, the whole clock is injected —
 * "today" and "now" are fixed — so no test depends on when it happens to run.
 */
class DayContextTest {

    private val today = LocalDate.of(2026, 6, 15)
    private var nextId = 1L

    private fun context(
        selected: LocalDate = today,
        hour: Int = 12,
        minute: Int = 0,
    ) = DayContext(selected, LocalDateTime.of(today, LocalTime.of(hour, minute)))

    private fun item(
        deadline: LocalTime? = null,
        daySection: DaySection? = null,
        status: ItemStatus = ItemStatus.Pending,
        isFlagged: Boolean = false,
    ) = PlanItem(
        id = nextId++,
        title = "Item",
        isFlagged = isFlagged,
        date = today,
        deadline = deadline,
        daySection = daySection,
        status = status,
    )

    private fun List<PlanItem>.ids() = map { it.id }

    // region isToday / currentSection / pastSections

    @ParameterizedTest(name = "{0} days from today, isToday = {1}")
    @MethodSource("daysFromToday")
    fun `isToday reflects whether the selected date is the current day`(offset: Long, expected: Boolean) {
        assertEquals(expected, context(selected = today.plusDays(offset)).isToday)
    }

    @ParameterizedTest(name = "at {0}:{1} the current section is {2}")
    @MethodSource("currentSections")
    fun `currentSection matches the section containing the current time while viewing today`(
        hour: Int,
        minute: Int,
        expected: DaySection,
    ) {
        assertEquals(expected, context(hour = hour, minute = minute).currentSection)
    }

    @Test
    fun `currentSection is null when not viewing today`() {
        assertNull(context(selected = today.minusDays(1)).currentSection)
        assertNull(context(selected = today.plusDays(1)).currentSection)
    }

    @Test
    fun `pastSections returns every section before the one containing the current time`() {
        assertEquals(
            listOf(DaySection.FirstThing, DaySection.Morning, DaySection.Midday),
            context(hour = 14).pastSections,
        )
    }

    @Test
    fun `pastSections is empty during the first section of the day`() {
        assertEquals(emptyList<DaySection>(), context(hour = 0, minute = 0).pastSections)
    }

    @Test
    fun `pastSections is empty when not viewing today`() {
        assertEquals(emptyList<DaySection>(), context(selected = today.plusDays(1)).pastSections)
    }

    // endregion

    // region anyTimeItems

    @ParameterizedTest(name = "section {0} and deadline {1} is included = {2}")
    @MethodSource("anyTimeCases")
    fun `anyTimeItems includes only items with no day section and no deadline`(
        daySection: DaySection?,
        deadline: LocalTime?,
        included: Boolean,
    ) {
        val subject = item(deadline = deadline, daySection = daySection)
        assertEquals(included, subject.id in context().anyTimeItems(listOf(subject)).ids())
    }

    // endregion

    // region nextUpcomingDeadline

    @Test
    fun `nextUpcomingDeadline returns the earliest pending deadline still ahead of now while viewing today`() {
        val items = listOf(
            item(deadline = LocalTime.of(9, 0)), // already passed
            item(deadline = LocalTime.of(15, 0)),
            item(deadline = LocalTime.of(13, 0)),
        )
        assertEquals(LocalTime.of(13, 0), context(hour = 12).nextUpcomingDeadline(items))
    }

    @Test
    fun `nextUpcomingDeadline counts a deadline exactly at the current minute as upcoming`() {
        val items = listOf(item(deadline = LocalTime.of(12, 0)), item(deadline = LocalTime.of(15, 0)))
        assertEquals(LocalTime.of(12, 0), context(hour = 12, minute = 0).nextUpcomingDeadline(items))
    }

    @Test
    fun `nextUpcomingDeadline falls back to the earliest deadline once every pending deadline today has passed`() {
        val items = listOf(item(deadline = LocalTime.of(10, 0)), item(deadline = LocalTime.of(8, 0)))
        assertEquals(LocalTime.of(8, 0), context(hour = 12).nextUpcomingDeadline(items))
    }

    @Test
    fun `nextUpcomingDeadline ignores completed and canceled items`() {
        val items = listOf(
            item(deadline = LocalTime.of(13, 0), status = ItemStatus.Completed),
            item(deadline = LocalTime.of(14, 0), status = ItemStatus.Canceled),
            item(deadline = LocalTime.of(16, 0)),
        )
        assertEquals(LocalTime.of(16, 0), context(hour = 12).nextUpcomingDeadline(items))
    }

    @Test
    fun `nextUpcomingDeadline returns null when there are no pending items with a deadline`() {
        val items = listOf(
            item(deadline = null),
            item(deadline = LocalTime.of(13, 0), status = ItemStatus.Completed),
        )
        assertNull(context().nextUpcomingDeadline(items))
        assertNull(context().nextUpcomingDeadline(emptyList()))
    }

    @Test
    fun `nextUpcomingDeadline uses the earliest deadline directly when not viewing today`() {
        val items = listOf(item(deadline = LocalTime.of(8, 0)), item(deadline = LocalTime.of(20, 0)))
        // 8:00 is well before the injected clock's 12:00, yet still wins on a different day.
        assertEquals(LocalTime.of(8, 0), context(selected = today.plusDays(1)).nextUpcomingDeadline(items))
        assertEquals(LocalTime.of(8, 0), context(selected = today.minusDays(1)).nextUpcomingDeadline(items))
    }

    // endregion

    // region outstandingFlaggedCount

    @ParameterizedTest(name = "flagged {0}, status {1}, counted = {2}")
    @MethodSource("flaggedCases")
    fun `outstandingFlaggedCount counts only pending items that are flagged`(
        isFlagged: Boolean,
        status: ItemStatus,
        counted: Boolean,
    ) {
        val subject = item(status = status, isFlagged = isFlagged)
        assertEquals(if (counted) 1 else 0, context().outstandingFlaggedCount(listOf(subject)))
    }

    @Test
    fun `outstandingFlaggedCount is zero for an empty list`() {
        assertEquals(0, context().outstandingFlaggedCount(emptyList()))
    }

    // endregion

    // region sectionPills

    @ParameterizedTest(name = "pills for {0}")
    @EnumSource(DaySection::class)
    fun `sectionPills includes only items assigned to the given section`(section: DaySection) {
        val matching = item(daySection = section)
        val others = DaySection.entries.filter { it != section }.map { item(daySection = it) }
        val result = context(selected = today.minusDays(7)).sectionPills(section, listOf(matching) + others)
        assertEquals(listOf(matching.id), result.ids())
    }

    @Test
    fun `sectionPills excludes items whose deadline has already passed today`() {
        val missed = item(deadline = LocalTime.of(11, 0), daySection = DaySection.Morning)
        val notMissed = item(deadline = LocalTime.of(13, 0), daySection = DaySection.Morning)
        val result = context(hour = 12).sectionPills(DaySection.Morning, listOf(missed, notMissed))
        assertEquals(listOf(notMissed.id), result.ids())
    }

    // endregion

    // region deadlineRows

    @Test
    fun `deadlineRows includes only unsectioned items whose deadline falls in that section, earliest first`() {
        val earlier = item(deadline = LocalTime.of(17, 0))
        val later = item(deadline = LocalTime.of(18, 0))
        val wrongSection = item(deadline = LocalTime.of(8, 0))
        val hasDaySection = item(deadline = LocalTime.of(17, 30), daySection = DaySection.Evening)
        val result = context(selected = today.minusDays(7))
            .deadlineRows(DaySection.Evening, listOf(later, earlier, wrongSection, hasDaySection))
        assertEquals(listOf(earlier.id, later.id), result.ids())
    }

    @Test
    fun `deadlineRows excludes items whose deadline has already passed today`() {
        val missed = item(deadline = LocalTime.of(11, 0))
        val notMissed = item(deadline = LocalTime.of(13, 0))
        val context = context(hour = 12)
        assertEquals(emptyList<Long>(), context.deadlineRows(DaySection.Morning, listOf(missed)).ids())
        assertEquals(listOf(notMissed.id), context.deadlineRows(DaySection.Afternoon, listOf(notMissed)).ids())
    }

    // endregion

    // region missed deadlines

    @Test
    fun `missedDeadlineItems returns only pending items with a passed deadline, earliest first`() {
        val missedEarlier = item(deadline = LocalTime.of(10, 0))
        val missedLater = item(deadline = LocalTime.of(11, 0))
        val notYetMissed = item(deadline = LocalTime.of(13, 0))
        val completedPastDeadline = item(deadline = LocalTime.of(11, 0), status = ItemStatus.Completed)
        val result = context(hour = 12).missedDeadlineItems(
            listOf(missedLater, missedEarlier, notYetMissed, completedPastDeadline),
        )
        assertEquals(listOf(missedEarlier.id, missedLater.id), result.ids())
    }

    @ParameterizedTest(name = "{0} days from today, {1}, deadline {2}, missed = {3}")
    @MethodSource("missedCases")
    fun `isDeadlineMissed is true only for pending items with a passed deadline while viewing today`(
        daysFromToday: Long,
        status: ItemStatus,
        deadline: LocalTime,
        expected: Boolean,
    ) {
        val subject = item(deadline = deadline, status = status)
        assertEquals(expected, context(selected = today.plusDays(daysFromToday), hour = 12).isDeadlineMissed(subject))
    }

    @Test
    fun `isDeadlineMissed is false for items without a deadline`() {
        assertFalse(context().isDeadlineMissed(item(deadline = null)))
    }

    @Test
    fun `isDeadlineMissed is false for a deadline at exactly the current minute`() {
        assertFalse(context(hour = 12, minute = 0).isDeadlineMissed(item(deadline = LocalTime.of(12, 0))))
        assertTrue(context(hour = 12, minute = 1).isDeadlineMissed(item(deadline = LocalTime.of(12, 0))))
    }

    // endregion

    companion object {
        @JvmStatic
        fun daysFromToday(): Stream<Arguments> = Stream.of(
            arguments(-30L, false),
            arguments(-1L, false),
            arguments(0L, true),
            arguments(1L, false),
        )

        @JvmStatic
        fun currentSections(): Stream<Arguments> = Stream.of(
            arguments(0, 0, DaySection.FirstThing),
            arguments(7, 30, DaySection.Morning),
            arguments(12, 0, DaySection.Midday),
            arguments(16, 59, DaySection.Afternoon),
            arguments(19, 15, DaySection.Evening),
            arguments(23, 59, DaySection.Bedtime),
        )

        @JvmStatic
        fun anyTimeCases(): Stream<Arguments> = Stream.of(
            arguments(null, null, true),
            arguments(DaySection.Morning, null, false),
            arguments(null, LocalTime.of(9, 0), false),
            arguments(DaySection.Evening, LocalTime.of(18, 0), false),
        )

        @JvmStatic
        fun flaggedCases(): Stream<Arguments> = Stream.of(
            arguments(true, ItemStatus.Pending, true),
            arguments(false, ItemStatus.Pending, false),
            arguments(true, ItemStatus.Completed, false),
            arguments(true, ItemStatus.Canceled, false),
        )

        @JvmStatic
        fun missedCases(): Stream<Arguments> = Stream.of(
            arguments(0L, ItemStatus.Pending, LocalTime.of(11, 0), true),
            arguments(0L, ItemStatus.Pending, LocalTime.of(13, 0), false),
            arguments(0L, ItemStatus.Completed, LocalTime.of(11, 0), false),
            arguments(0L, ItemStatus.Canceled, LocalTime.of(11, 0), false),
            arguments(-1L, ItemStatus.Pending, LocalTime.of(11, 0), false),
            arguments(1L, ItemStatus.Pending, LocalTime.of(11, 0), false),
        )
    }
}
