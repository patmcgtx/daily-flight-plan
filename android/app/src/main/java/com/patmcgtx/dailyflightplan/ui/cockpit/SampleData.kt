package com.patmcgtx.dailyflightplan.ui.cockpit

import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/** Fixed sample content for Compose previews (the counterpart of the iOS in-memory sample container). */
object SampleData {

    private val date = LocalDate.of(2026, 6, 15)

    fun items(): List<PlanItem> {
        var id = 1L
        fun item(
            title: String,
            section: DaySection? = null,
            deadline: LocalTime? = null,
            status: ItemStatus = ItemStatus.Pending,
            flagged: Boolean = false,
            notes: String = "",
        ) = PlanItem(id = id++, title = title, notes = notes, isFlagged = flagged, date = date, deadline = deadline, daySection = section, status = status)

        return listOf(
            item("Stretch", DaySection.FirstThing, status = ItemStatus.Completed),
            item("Coffee", DaySection.Morning, status = ItemStatus.Completed),
            item("Review PRs", DaySection.Morning, flagged = true),
            item("Standup", deadline = LocalTime.of(9, 30)),
            item("Write release notes", DaySection.Midday, notes = "Include the new filters"),
            item("Lunch with Sam", deadline = LocalTime.of(12, 15)),
            item("Dentist", deadline = LocalTime.of(14, 30), flagged = true),
            item("Inbox zero", DaySection.Afternoon),
            item("Call the plumber", DaySection.Afternoon),
            item("Cook dinner", DaySection.Evening),
            item("Read a chapter", DaySection.Bedtime),
            item("Renew passport"),
            item("Plan the weekend"),
        )
    }

    fun state(
        now: LocalDateTime = LocalDateTime.of(date, LocalTime.of(12, 0)),
        showCompleted: Boolean = false,
    ) = CockpitUiState(
        date = date,
        now = now,
        items = items(),
        day = Day(date, flightName = "", intention = "Ship the release"),
        showCompleted = showCompleted,
        expandedSections = setOf(DaySection.Midday, DaySection.Afternoon),
    )
}
