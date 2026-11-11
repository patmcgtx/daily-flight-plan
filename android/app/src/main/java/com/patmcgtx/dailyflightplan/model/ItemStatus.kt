package com.patmcgtx.dailyflightplan.model

/**
 * Deferring a one-off item is a date change (move it to tomorrow), not a status — same as iOS.
 */
enum class ItemStatus { Pending, Completed, Canceled }
