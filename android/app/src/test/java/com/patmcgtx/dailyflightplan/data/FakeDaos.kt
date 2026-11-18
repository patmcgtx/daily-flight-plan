package com.patmcgtx.dailyflightplan.data

import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.PlanItem
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map

/** In-memory stand-ins for the Room DAOs, so repository rules can be tested on the JVM. */
class FakePlanItemDao : PlanItemDao {
    private val rows = MutableStateFlow<List<PlanItem>>(emptyList())
    private var nextId = 1L

    val all: List<PlanItem> get() = rows.value

    override fun observeForDate(date: LocalDate): Flow<List<PlanItem>> = rows.map { items ->
        // Same ordering as the real query: timed items first by time, then the rest by id.
        items.filter { it.date == date }
            .sortedWith(compareBy<PlanItem> { it.deadline == null }.thenBy { it.deadline }.thenBy { it.id })
    }

    override suspend fun get(id: Long): PlanItem? = rows.value.firstOrNull { it.id == id }

    override suspend fun insert(item: PlanItem): Long {
        val id = nextId++
        rows.value = rows.value + item.copy(id = id)
        return id
    }

    override suspend fun update(item: PlanItem) {
        rows.value = rows.value.map { if (it.id == item.id) item else it }
    }

    override suspend fun delete(item: PlanItem) {
        rows.value = rows.value.filterNot { it.id == item.id }
    }
}

class FakeDayDao : DayDao {
    private val rows = MutableStateFlow<Map<LocalDate, Day>>(emptyMap())

    val all: Map<LocalDate, Day> get() = rows.value

    /** How many writes (upserts + deletes) reached the DAO, to assert "no row was touched". */
    var writeCount = 0
        private set

    override fun observe(date: LocalDate): Flow<Day?> = rows.map { it[date] }

    override suspend fun get(date: LocalDate): Day? = rows.value[date]

    override suspend fun upsert(day: Day) {
        writeCount++
        rows.value = rows.value + (day.date to day)
    }

    override suspend fun delete(date: LocalDate) {
        writeCount++
        rows.value = rows.value - date
    }
}
