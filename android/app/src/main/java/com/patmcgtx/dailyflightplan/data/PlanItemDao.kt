package com.patmcgtx.dailyflightplan.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.patmcgtx.dailyflightplan.model.PlanItem
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow

@Dao
interface PlanItemDao {

    /** All items on [date] — every status, including canceled — timed ones first, by time. */
    @Query("SELECT * FROM plan_items WHERE date = :date ORDER BY deadline IS NULL, deadline, id")
    fun observeForDate(date: LocalDate): Flow<List<PlanItem>>

    @Query("SELECT * FROM plan_items WHERE id = :id")
    suspend fun get(id: Long): PlanItem?

    /** Returns the generated row id. */
    @Insert
    suspend fun insert(item: PlanItem): Long

    @Update
    suspend fun update(item: PlanItem)

    @Delete
    suspend fun delete(item: PlanItem)
}
