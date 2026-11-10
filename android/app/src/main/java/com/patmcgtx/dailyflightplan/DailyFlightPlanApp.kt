package com.patmcgtx.dailyflightplan

import android.app.Application
import com.patmcgtx.dailyflightplan.data.AppDatabase
import com.patmcgtx.dailyflightplan.data.PlanRepository

/** Application entry point; owns the process-wide repository (plain dependency injection, no framework). */
class DailyFlightPlanApp : Application() {

    val repository: PlanRepository by lazy {
        val database = AppDatabase.getInstance(this)
        PlanRepository(database.planItemDao(), database.dayDao())
    }
}
