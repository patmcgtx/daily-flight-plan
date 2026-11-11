package com.patmcgtx.dailyflightplan.model

import java.time.LocalDate
import java.time.LocalTime
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

/** Ported from the iOS `ItemFormViewModelTests`, minus routines, categories, and SwiftData. */
class ItemFormStateTest {

    private val june15 = LocalDate.of(2026, 6, 15)
    private val nineAm = LocalTime.of(9, 0)

    private fun blank(section: DaySection? = null) = ItemFormState.forNew(june15, section, nineAm)

    // region isValid

    @ParameterizedTest(name = "\"{0}\" is valid = {1}")
    @MethodSource("titles")
    fun `isValid is true only when the title has non-whitespace content`(title: String, expected: Boolean) {
        assertEquals(expected, blank().copy(title = title).isValid)
    }

    @ParameterizedTest(name = "saving \"{0}\" produces nothing")
    @MethodSource("blankTitles")
    fun `toPlanItem does nothing when the title is empty or whitespace-only`(title: String) {
        assertNull(blank().copy(title = title).toPlanItem())
    }

    // endregion

    // region Starting states

    @Test
    fun `A new form takes the date and section it is opened with and defaults to untimed`() {
        val form = ItemFormState.forNew(june15, DaySection.Afternoon, LocalTime.of(14, 30))
        assertEquals(june15, form.date)
        assertEquals(DaySection.Afternoon, form.daySection)
        assertFalse(form.hasDeadline)
        assertEquals(LocalTime.of(14, 30), form.deadline)
        assertEquals("", form.title)
        assertFalse(form.isFlagged)
    }

    @Test
    fun `A new form with no section is an Open item`() {
        assertNull(blank().daySection)
    }

    @Test
    fun `Editing a timed item shows its time and no segment`() {
        val item = PlanItem(id = 4, title = "Dentist", notes = "n", isFlagged = true, date = june15, deadline = LocalTime.of(15, 45))
        val form = ItemFormState.from(item, nineAm)
        assertEquals(true, form.hasDeadline)
        assertEquals(LocalTime.of(15, 45), form.deadline)
        assertEquals("Dentist", form.title)
        assertEquals("n", form.notes)
        assertEquals(true, form.isFlagged)
    }

    @Test
    fun `Editing an untimed item turns the time off and seeds the picker with the default time`() {
        val item = PlanItem(id = 4, title = "Run", date = june15, daySection = DaySection.Morning)
        val form = ItemFormState.from(item, nineAm)
        assertFalse(form.hasDeadline)
        assertEquals(nineAm, form.deadline)
        assertEquals(DaySection.Morning, form.daySection)
    }

    // endregion

    // region Creating

    @Test
    fun `Saving a new form creates a pending item with the trimmed title`() {
        val saved = blank(DaySection.Evening).copy(title = "  Buy milk  ").toPlanItem()!!
        assertEquals("Buy milk", saved.title)
        assertEquals(DaySection.Evening, saved.daySection)
        assertNull(saved.deadline)
        assertEquals(june15, saved.date)
        assertEquals(ItemStatus.Pending, saved.status)
        assertEquals(0L, saved.id)
    }

    @Test
    fun `Saving a timed item keeps the time to the minute and clears the section`() {
        val form = blank(DaySection.Morning).copy(title = "Dentist", hasDeadline = true, deadline = LocalTime.of(15, 45, 30, 123))
        val saved = form.toPlanItem()!!
        assertEquals(LocalTime.of(15, 45), saved.deadline)
        assertNull(saved.daySection)
    }

    @Test
    fun `Turning the time off drops it but keeps the chosen section`() {
        val form = blank(DaySection.Midday).copy(title = "Lunch", hasDeadline = false, deadline = LocalTime.of(12, 15))
        val saved = form.toPlanItem()!!
        assertNull(saved.deadline)
        assertEquals(DaySection.Midday, saved.daySection)
    }

    @Test
    fun `Notes are saved as typed and the flag is carried over`() {
        val saved = blank().copy(title = "T", notes = "  spaced notes \n", isFlagged = true).toPlanItem()!!
        assertEquals("  spaced notes \n", saved.notes)
        assertEquals(true, saved.isFlagged)
    }

    // endregion

    // region Editing

    @Test
    fun `Saving an edit changes the form's fields but keeps the item's id and status`() {
        val existing = PlanItem(id = 7, title = "Old", notes = "old", date = june15, status = ItemStatus.Completed)
        val saved = ItemFormState.from(existing, nineAm)
            .copy(title = "New", notes = "new", isFlagged = true)
            .toPlanItem(existing)!!
        assertEquals(existing.copy(title = "New", notes = "new", isFlagged = true), saved)
    }

    @Test
    fun `Saving an edit can move the item to another day`() {
        val existing = PlanItem(id = 7, title = "Task", date = june15)
        val saved = ItemFormState.from(existing, nineAm).copy(date = june15.plusDays(5)).toPlanItem(existing)!!
        assertEquals(june15.plusDays(5), saved.date)
        assertEquals(7L, saved.id)
    }

    @Test
    fun `Editing a sectioned item into a timed one clears its section`() {
        val existing = PlanItem(id = 7, title = "Task", date = june15, daySection = DaySection.Evening)
        val saved = ItemFormState.from(existing, nineAm).copy(hasDeadline = true, deadline = LocalTime.of(18, 0)).toPlanItem(existing)!!
        assertEquals(LocalTime.of(18, 0), saved.deadline)
        assertNull(saved.daySection)
    }

    @Test
    fun `Editing a timed item into an untimed one clears its time`() {
        val existing = PlanItem(id = 7, title = "Task", date = june15, deadline = LocalTime.of(18, 0))
        val saved = ItemFormState.from(existing, nineAm).copy(hasDeadline = false, daySection = DaySection.Evening).toPlanItem(existing)!!
        assertNull(saved.deadline)
        assertEquals(DaySection.Evening, saved.daySection)
    }

    @Test
    fun `A blank title blocks saving an edit too`() {
        val existing = PlanItem(id = 7, title = "Task", date = june15)
        assertNull(ItemFormState.from(existing, nineAm).copy(title = "  ").toPlanItem(existing))
    }

    // endregion

    companion object {
        @JvmStatic
        fun titles(): Stream<Arguments> = Stream.of(
            arguments("Buy milk", true),
            arguments("", false),
            arguments("   ", false),
            arguments("  Buy milk  ", true),
        )

        @JvmStatic
        fun blankTitles(): Stream<Arguments> = Stream.of(arguments(""), arguments("   "))
    }
}
