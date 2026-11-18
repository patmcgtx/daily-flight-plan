package com.patmcgtx.dailyflightplan.model

/** How much of a set of items is done. */
data class Progress(val completed: Int, val total: Int) {

    /** 0..1 fraction complete; 0 when there is nothing to do. */
    val fraction: Float get() = if (total > 0) completed.toFloat() / total else 0f

    /** True only when there is something to do and all of it is done. */
    val isAllDone: Boolean get() = total > 0 && completed == total

    companion object {
        fun of(items: List<PlanItem>) = Progress(items.count { it.status == ItemStatus.Completed }, items.size)
    }
}

/** Items that still count toward a day: everything except canceled ones. */
fun List<PlanItem>.excludingCanceled(): List<PlanItem> = filter { it.status != ItemStatus.Canceled }

/**
 * The day view's status filter. By default only pending items show; with [showCompleted],
 * completed and canceled items are revealed alongside them (matching the iOS Cockpit).
 */
fun List<PlanItem>.matchingStatusFilter(showCompleted: Boolean): List<PlanItem> =
    filter { showCompleted || it.status == ItemStatus.Pending }
