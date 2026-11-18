package com.patmcgtx.dailyflightplan.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import java.time.LocalDate
import java.time.LocalTime
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Runs the real DAOs against an in-memory SQLite database on a device/emulator
 * (`./gradlew :app:connectedDebugAndroidTest`). Method names are camelCase sentences because
 * backticked names with spaces aren't allowed in instrumented tests below minSdk 30.
 */
@RunWith(AndroidJUnit4::class)
class AppDatabaseTest {

    private lateinit var db: AppDatabase
    private val items get() = db.planItemDao()
    private val days get() = db.dayDao()
    private val june15 = LocalDate.of(2026, 6, 15)

    @Before
    fun createDatabase() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java).build()
    }

    @After
    fun closeDatabase() = db.close()

    private fun item(title: String, date: LocalDate = june15, deadline: LocalTime? = null) =
        PlanItem(title = title, date = date, deadline = deadline)

    // region PlanItemDao

    @Test
    fun insertAssignsAnIdAndRoundTripsEveryField() = runBlocking {
        val original = PlanItem(
            title = "Dentist",
            notes = "Bring forms",
            isFlagged = true,
            date = june15,
            deadline = LocalTime.of(14, 30),
            daySection = DaySection.Afternoon,
            status = ItemStatus.Completed,
        )
        val id = items.insert(original)

        assertEquals(original.copy(id = id), items.get(id))
        assertEquals(true, id > 0)
    }

    @Test
    fun nullDeadlineAndSectionRoundTripAsNull() = runBlocking {
        val id = items.insert(item("Someday"))
        val stored = items.get(id)!!
        assertNull(stored.deadline)
        assertNull(stored.daySection)
    }

    @Test
    fun timesAndDatesAtTheEdgesOfTheirRangesRoundTrip() = runBlocking {
        val midnight = items.insert(item("Midnight", LocalDate.of(1970, 1, 1), LocalTime.MIDNIGHT))
        val lastMinute = items.insert(item("Last minute", LocalDate.of(2026, 12, 31), LocalTime.of(23, 59)))
        assertEquals(LocalDate.of(1970, 1, 1) to LocalTime.MIDNIGHT, items.get(midnight)!!.let { it.date to it.deadline })
        assertEquals(LocalDate.of(2026, 12, 31) to LocalTime.of(23, 59), items.get(lastMinute)!!.let { it.date to it.deadline })
    }

    @Test
    fun observeForDateReturnsOnlyThatDatesItems() = runBlocking {
        val today = items.insert(item("Today"))
        items.insert(item("Tomorrow", june15.plusDays(1)))
        items.insert(item("Yesterday", june15.minusDays(1)))

        assertEquals(listOf(today), items.observeForDate(june15).first().map { it.id })
    }

    @Test
    fun observeForDateOrdersTimedItemsFirstByTimeThenTheRestByInsertOrder() = runBlocking {
        val untimedA = items.insert(item("Untimed A"))
        val late = items.insert(item("Late", deadline = LocalTime.of(18, 0)))
        val untimedB = items.insert(item("Untimed B"))
        val early = items.insert(item("Early", deadline = LocalTime.of(8, 0)))

        assertEquals(
            listOf(early, late, untimedA, untimedB),
            items.observeForDate(june15).first().map { it.id },
        )
    }

    @Test
    fun observeForDateIncludesCompletedAndCanceledItems() = runBlocking {
        items.insert(item("Pending"))
        items.insert(item("Done").copy(status = ItemStatus.Completed))
        items.insert(item("Canceled").copy(status = ItemStatus.Canceled))

        assertEquals(
            setOf(ItemStatus.Pending, ItemStatus.Completed, ItemStatus.Canceled),
            items.observeForDate(june15).first().map { it.status }.toSet(),
        )
    }

    @Test
    fun observeForDateReEmitsWhenAnItemChanges() = runBlocking {
        val id = items.insert(item("Task"))
        withTimeout(10_000) {
            // Undispatched, so the collector is already waiting when the update lands.
            val completed = async(start = CoroutineStart.UNDISPATCHED) {
                items.observeForDate(june15).first { list -> list.any { it.status == ItemStatus.Completed } }
            }
            items.update(items.get(id)!!.copy(status = ItemStatus.Completed))
            assertEquals(listOf(id), completed.await().map { it.id })
        }
    }

    @Test
    fun updateReplacesTheStoredRow() = runBlocking {
        val id = items.insert(item("Old"))
        items.update(items.get(id)!!.copy(title = "New", isFlagged = true))
        assertEquals("New", items.get(id)!!.title)
        assertEquals(true, items.get(id)!!.isFlagged)
    }

    @Test
    fun deleteRemovesOnlyThatItem() = runBlocking {
        val keep = items.insert(item("Keep"))
        val drop = items.insert(item("Drop"))
        items.delete(items.get(drop)!!)

        assertNull(items.get(drop))
        assertEquals(listOf(keep), items.observeForDate(june15).first().map { it.id })
    }

    // endregion

    // region DayDao

    @Test
    fun getReturnsNullForADayThatWasNeverCustomized() = runBlocking {
        assertNull(days.get(june15))
        assertNull(days.observe(june15).first())
    }

    @Test
    fun upsertInsertsThenReplacesTheRowForTheSameDate() = runBlocking {
        days.upsert(Day(june15, flightName = "Deep Work"))
        days.upsert(Day(june15, flightName = "Deep Work", intention = "Ship it"))

        assertEquals(Day(june15, "Deep Work", "Ship it"), days.get(june15))
    }

    @Test
    fun daysAreKeyedByDateSoDifferentDatesDoNotCollide() = runBlocking {
        days.upsert(Day(june15, intention = "A"))
        days.upsert(Day(june15.plusDays(1), intention = "B"))

        assertEquals("A", days.get(june15)!!.intention)
        assertEquals("B", days.get(june15.plusDays(1))!!.intention)
    }

    @Test
    fun deleteRemovesOnlyThatDaysRow() = runBlocking {
        days.upsert(Day(june15, intention = "A"))
        days.upsert(Day(june15.plusDays(1), intention = "B"))
        days.delete(june15)

        assertNull(days.get(june15))
        assertEquals("B", days.get(june15.plusDays(1))!!.intention)
    }

    // endregion

    @Test
    fun theRepositoryWorksEndToEndAgainstTheRealDatabase() = runBlocking {
        val repository = PlanRepository(items, days)
        val id = repository.addItem(item("Run", deadline = LocalTime.of(7, 0)))
        repository.toggleFlag(items.get(id)!!)
        repository.deferToTomorrow(items.get(id)!!)
        repository.setFlightName(june15, "Deep Work")
        repository.setFlightName(june15, "")

        assertEquals(emptyList<Long>(), repository.observeItems(june15).first().map { it.id })
        val moved = repository.observeItems(june15.plusDays(1)).first().single()
        assertEquals(true, moved.isFlagged)
        assertEquals(LocalTime.of(7, 0), moved.deadline)
        assertNull(repository.observeDay(june15).first())
    }
}
