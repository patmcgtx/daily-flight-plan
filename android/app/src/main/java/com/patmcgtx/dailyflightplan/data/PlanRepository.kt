package com.patmcgtx.dailyflightplan.data

import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * The single entry point the UI layer uses to read and change plan data. It depends on the DAO
 * interfaces rather than the database, so its rules are unit-tested on the JVM with fake DAOs.
 */
class PlanRepository(
    private val items: PlanItemDao,
    private val days: DayDao,
) {

    /** Serializes read-modify-write edits to a day so two quick edits can't clobber each other. */
    private val dayEditLock = Mutex()

    // region Items

    /** Every item on [date], including canceled ones; filtering is the caller's job. */
    fun observeItems(date: LocalDate): Flow<List<PlanItem>> = items.observeForDate(date)

    /** Returns the new item's id. */
    suspend fun addItem(item: PlanItem): Long = items.insert(item)

    suspend fun updateItem(item: PlanItem) = items.update(item)

    suspend fun deleteItem(item: PlanItem) = items.delete(item)

    suspend fun setStatus(item: PlanItem, status: ItemStatus) = items.update(item.copy(status = status))

    suspend fun toggleFlag(item: PlanItem) = items.update(item.copy(isFlagged = !item.isFlagged))

    /** Moves the item to the next day, keeping its time of day. */
    suspend fun deferToTomorrow(item: PlanItem) = items.update(item.copy(date = item.date.plusDays(1)))

    // endregion

    // region Day details (flight name + destination)

    /** Emits null when the user hasn't customized [date]. */
    fun observeDay(date: LocalDate): Flow<Day?> = days.observe(date)

    /**
     * Stores [text] as the flight name for [date]. Blank text, or text equal to the default
     * number, is stored as "" so the name keeps tracking the default. A day left with nothing
     * customized is deleted rather than kept as an empty row.
     */
    suspend fun setFlightName(date: LocalDate, text: String) = editDay(date) { day ->
        val trimmed = text.trim()
        val isDefault = trimmed.isEmpty() || trimmed == Day.defaultFlightNumber(date)
        day.withFlightName(if (isDefault) "" else text)
    }

    /** Stores [text] as the day's destination note; clearing it deletes a day with nothing else set. */
    suspend fun setIntention(date: LocalDate, text: String) = editDay(date) { it.withIntention(text) }

    private suspend fun editDay(date: LocalDate, edit: (Day) -> Day) = dayEditLock.withLock {
        val existing = days.get(date)
        val edited = edit(existing ?: Day(date))
        when {
            !edited.isBlank -> days.upsert(edited)
            existing != null -> days.delete(date)
            else -> Unit // nothing customized and nothing stored: leave no row behind
        }
    }

    // endregion
}
