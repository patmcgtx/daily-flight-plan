package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

class ProgressTest {

    private fun item(status: ItemStatus) =
        PlanItem(title = "Item", date = LocalDate.of(2026, 6, 15), status = status)

    @Test
    fun `Progress of counts completed items against the total`() {
        val items = listOf(
            item(ItemStatus.Completed),
            item(ItemStatus.Completed),
            item(ItemStatus.Pending),
            item(ItemStatus.Pending),
        )
        assertEquals(Progress(2, 4), Progress.of(items))
    }

    @ParameterizedTest(name = "{0} of {1} is fraction {2}, all done = {3}")
    @MethodSource("fractions")
    fun `Fraction and all-done reflect completed over total`(
        completed: Int,
        total: Int,
        fraction: Float,
        allDone: Boolean,
    ) {
        val progress = Progress(completed, total)
        assertEquals(fraction, progress.fraction)
        assertEquals(allDone, progress.isAllDone)
    }

    @Test
    fun `An empty set is never reported as all done and has zero fraction`() {
        assertFalse(Progress.of(emptyList()).isAllDone)
        assertEquals(0f, Progress.of(emptyList()).fraction)
    }

    @Test
    fun `excludingCanceled drops only canceled items`() {
        val pending = item(ItemStatus.Pending)
        val done = item(ItemStatus.Completed)
        val canceled = item(ItemStatus.Canceled)
        assertEquals(listOf(pending, done), listOf(pending, canceled, done).excludingCanceled())
    }

    @ParameterizedTest(name = "{0} is shown with showCompleted = {1}: {2}")
    @MethodSource("statusFilterCases")
    fun `matchingStatusFilter shows only pending items unless completed items are revealed`(
        status: ItemStatus,
        showCompleted: Boolean,
        shown: Boolean,
    ) {
        val subject = item(status)
        assertEquals(shown, subject in listOf(subject).matchingStatusFilter(showCompleted))
    }

    @Test
    fun `Revealing completed items keeps pending items too`() {
        val items = ItemStatus.entries.map(::item)
        assertTrue(items.matchingStatusFilter(showCompleted = true).size == items.size)
    }

    companion object {
        @JvmStatic
        fun fractions(): Stream<Arguments> = Stream.of(
            arguments(0, 0, 0f, false),
            arguments(0, 4, 0f, false),
            arguments(1, 4, 0.25f, false),
            arguments(4, 4, 1f, true),
        )

        @JvmStatic
        fun statusFilterCases(): Stream<Arguments> = Stream.of(
            arguments(ItemStatus.Pending, false, true),
            arguments(ItemStatus.Completed, false, false),
            arguments(ItemStatus.Canceled, false, false),
            arguments(ItemStatus.Pending, true, true),
            arguments(ItemStatus.Completed, true, true),
            arguments(ItemStatus.Canceled, true, true),
        )
    }
}
