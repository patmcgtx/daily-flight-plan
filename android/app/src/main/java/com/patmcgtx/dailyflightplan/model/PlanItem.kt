package com.patmcgtx.dailyflightplan.model

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.time.LocalDate
import java.time.LocalTime

/**
 * A single task on the flight plan. v1 subset of the iOS `PlanItem`: no routines/templates,
 * categories, or reminder links (see `docs/android-port-plan.md`). Also the Room entity for the
 * `plan_items` table; column types are handled by `data/Converters`.
 */
@Entity(tableName = "plan_items", indices = [Index("date")])
data class PlanItem(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val notes: String = "",
    val isFlagged: Boolean = false,
    /** The calendar day this item belongs to. */
    val date: LocalDate,
    /** A specific clock time. Null means the item is not time-specific. */
    val deadline: LocalTime? = null,
    /** The time-of-day section. Null when the item has a deadline or is explicitly "any time". */
    val daySection: DaySection? = null,
    val status: ItemStatus = ItemStatus.Pending,
)
