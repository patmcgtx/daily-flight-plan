package com.patmcgtx.dailyflightplan.data

import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import java.time.LocalDate
import java.time.LocalTime
import java.util.stream.Stream
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

/** Repository rules, tested against fake DAOs; the SQL itself is covered by the instrumented DAO tests. */
class PlanRepositoryTest {

    private val june15 = LocalDate.of(2026, 6, 15)
    private val itemDao = FakePlanItemDao()
    private val dayDao = FakeDayDao()
    private val repository = PlanRepository(itemDao, dayDao)

    private suspend fun add(
        title: String = "Item",
        date: LocalDate = june15,
        deadline: LocalTime? = null,
        daySection: DaySection? = null,
    ): PlanItem {
        val id = repository.addItem(PlanItem(title = title, date = date, deadline = deadline, daySection = daySection))
        return itemDao.get(id)!!
    }

    // region Items

    @Test
    fun `addItem returns the generated id and the item shows up for its date`() = runTest {
        val id = repository.addItem(PlanItem(title = "Call mom", date = june15))
        assertEquals(listOf(id), repository.observeItems(june15).first().map { it.id })
    }

    @Test
    fun `observeItems returns only the items on the requested date`() = runTest {
        val today = add("Today")
        add("Tomorrow", date = june15.plusDays(1))
        assertEquals(listOf(today.id), repository.observeItems(june15).first().map { it.id })
    }

    @ParameterizedTest(name = "setStatus to {0}")
    @MethodSource("statuses")
    fun `setStatus changes only the status`(status: ItemStatus) = runTest {
        val item = add(daySection = DaySection.Morning)
        repository.setStatus(item, status)
        assertEquals(item.copy(status = status), itemDao.get(item.id))
    }

    @Test
    fun `toggleFlag flips the flag each time it is called`() = runTest {
        val item = add()
        repository.toggleFlag(item)
        assertEquals(true, itemDao.get(item.id)!!.isFlagged)
        repository.toggleFlag(itemDao.get(item.id)!!)
        assertEquals(false, itemDao.get(item.id)!!.isFlagged)
    }

    @Test
    fun `deferToTomorrow moves the item one day forward and keeps its time and section`() = runTest {
        val timed = add(deadline = LocalTime.of(14, 30))
        val sectioned = add(daySection = DaySection.Evening)
        repository.deferToTomorrow(timed)
        repository.deferToTomorrow(sectioned)
        assertEquals(timed.copy(date = june15.plusDays(1)), itemDao.get(timed.id))
        assertEquals(sectioned.copy(date = june15.plusDays(1)), itemDao.get(sectioned.id))
    }

    @Test
    fun `deferToTomorrow rolls over a month boundary`() = runTest {
        val item = add(date = LocalDate.of(2026, 6, 30))
        repository.deferToTomorrow(item)
        assertEquals(LocalDate.of(2026, 7, 1), itemDao.get(item.id)!!.date)
    }

    @Test
    fun `updateItem replaces the stored item and deleteItem removes it`() = runTest {
        val item = add("Old title")
        repository.updateItem(item.copy(title = "New title", notes = "n"))
        assertEquals("New title", itemDao.get(item.id)!!.title)
        repository.deleteItem(itemDao.get(item.id)!!)
        assertNull(itemDao.get(item.id))
    }

    // endregion

    // region Flight name

    @ParameterizedTest(name = "typing \"{0}\" stores {1}")
    @MethodSource("flightNameInputs")
    fun `setFlightName stores a custom name and ignores blank or default text`(typed: String, stored: String?) = runTest {
        repository.setFlightName(june15, typed)
        assertEquals(stored, dayDao.all[june15]?.flightName)
        if (stored == null) assertEquals(0, dayDao.writeCount)
    }

    @Test
    fun `setFlightName caps the stored name at the maximum length`() = runTest {
        repository.setFlightName(june15, "A".repeat(100))
        assertEquals(Day.MAX_FLIGHT_NAME_LENGTH, dayDao.all[june15]!!.flightName.length)
    }

    @Test
    fun `Resetting the flight name to the default deletes a day with nothing else customized`() = runTest {
        repository.setFlightName(june15, "Deep Work")
        repository.setFlightName(june15, Day.defaultFlightNumber(june15))
        assertNull(dayDao.all[june15])
    }

    @Test
    fun `Resetting the flight name keeps the day when it still has a destination`() = runTest {
        repository.setIntention(june15, "Ship it")
        repository.setFlightName(june15, "Deep Work")
        repository.setFlightName(june15, "")
        assertEquals(Day(june15, flightName = "", intention = "Ship it"), dayDao.all[june15])
    }

    // endregion

    // region Destination

    @Test
    fun `setIntention creates the day on first edit and updates it afterwards`() = runTest {
        repository.setIntention(june15, "Ship")
        repository.setIntention(june15, "Ship the release")
        assertEquals(Day(june15, intention = "Ship the release"), dayDao.all[june15])
    }

    @Test
    fun `Clearing the destination deletes a day with nothing else customized`() = runTest {
        repository.setIntention(june15, "Ship it")
        repository.setIntention(june15, "   ")
        assertNull(dayDao.all[june15])
    }

    @Test
    fun `Clearing the destination keeps the day when it still has a custom flight name`() = runTest {
        repository.setFlightName(june15, "Deep Work")
        repository.setIntention(june15, "Ship it")
        repository.setIntention(june15, "")
        assertEquals(Day(june15, flightName = "Deep Work", intention = ""), dayDao.all[june15])
    }

    @Test
    fun `Blank destination text on a day with no row writes nothing`() = runTest {
        repository.setIntention(june15, "")
        assertEquals(0, dayDao.writeCount)
    }

    @Test
    fun `Editing one day never touches another`() = runTest {
        repository.setFlightName(june15, "Deep Work")
        repository.setIntention(june15.plusDays(1), "Rest")
        assertEquals("Deep Work", dayDao.all[june15]!!.flightName)
        assertEquals("", dayDao.all[june15]!!.intention)
        assertEquals("Rest", dayDao.all[june15.plusDays(1)]!!.intention)
    }

    @Test
    fun `observeDay emits null until the day is customized and then the day`() = runTest {
        assertNull(repository.observeDay(june15).first())
        repository.setIntention(june15, "Ship it")
        assertEquals("Ship it", repository.observeDay(june15).first()!!.intention)
    }

    // endregion

    companion object {
        @JvmStatic
        fun statuses(): Stream<Arguments> =
            ItemStatus.entries.stream().map { arguments(it) }

        @JvmStatic
        fun flightNameInputs(): Stream<Arguments> = Stream.of(
            arguments("", null),
            arguments("   ", null),
            arguments("DFP 20260615", null),
            arguments("  DFP 20260615  ", null),
            arguments("Deep Work", "Deep Work"),
            arguments("DFP 20260616", "DFP 20260616"), // another day's default number is a custom name here
        )
    }
}
