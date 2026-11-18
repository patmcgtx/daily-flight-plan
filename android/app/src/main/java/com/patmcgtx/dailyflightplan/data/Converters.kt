package com.patmcgtx.dailyflightplan.data

import androidx.room.TypeConverter
import java.time.LocalDate
import java.time.LocalTime

/**
 * Room column mappings for `java.time` types. Dates are stored as epoch days and times as
 * seconds of the day, so both sort and compare correctly in SQL. (Enums are stored by name,
 * which Room does on its own.)
 */
class Converters {

    @TypeConverter
    fun toLocalDate(epochDay: Long?): LocalDate? = epochDay?.let(LocalDate::ofEpochDay)

    @TypeConverter
    fun fromLocalDate(date: LocalDate?): Long? = date?.toEpochDay()

    @TypeConverter
    fun toLocalTime(secondOfDay: Int?): LocalTime? = secondOfDay?.let { LocalTime.ofSecondOfDay(it.toLong()) }

    @TypeConverter
    fun fromLocalTime(time: LocalTime?): Int? = time?.toSecondOfDay()
}
