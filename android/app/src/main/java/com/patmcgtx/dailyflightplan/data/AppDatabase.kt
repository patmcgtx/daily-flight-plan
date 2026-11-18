package com.patmcgtx.dailyflightplan.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.PlanItem

/** The app's local-only database. Schemas are exported to `app/schemas` for migration tests. */
@Database(entities = [PlanItem::class, Day::class], version = 1)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {

    abstract fun planItemDao(): PlanItemDao

    abstract fun dayDao(): DayDao

    companion object {
        private const val DATABASE_NAME = "daily-flight-plan.db"

        @Volatile
        private var instance: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    DATABASE_NAME,
                ).build().also { instance = it }
            }
    }
}
