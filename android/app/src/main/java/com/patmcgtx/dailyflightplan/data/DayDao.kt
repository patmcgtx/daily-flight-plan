package com.patmcgtx.dailyflightplan.data

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import com.patmcgtx.dailyflightplan.model.Day
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow

@Dao
interface DayDao {

    /** Emits null for a day the user hasn't customized. */
    @Query("SELECT * FROM days WHERE date = :date")
    fun observe(date: LocalDate): Flow<Day?>

    @Query("SELECT * FROM days WHERE date = :date")
    suspend fun get(date: LocalDate): Day?

    @Upsert
    suspend fun upsert(day: Day)

    @Query("DELETE FROM days WHERE date = :date")
    suspend fun delete(date: LocalDate)
}
