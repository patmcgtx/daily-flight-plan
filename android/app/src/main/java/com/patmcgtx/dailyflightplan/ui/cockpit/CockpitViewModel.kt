package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.patmcgtx.dailyflightplan.data.PlanRepository
import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.DayContext
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemFormState
import com.patmcgtx.dailyflightplan.model.ItemFormTarget
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import com.patmcgtx.dailyflightplan.model.Progress
import com.patmcgtx.dailyflightplan.model.SectionModel
import com.patmcgtx.dailyflightplan.model.excludingCanceled
import com.patmcgtx.dailyflightplan.model.matchingStatusFilter
import com.patmcgtx.dailyflightplan.model.sectionModel
import java.time.Clock
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Everything the Cockpit screen draws, for one day at one moment. Pure data; derived values are lazy. */
data class CockpitUiState(
    val date: LocalDate,
    val now: LocalDateTime,
    /** Every item on [date], including canceled ones. */
    val items: List<PlanItem>,
    val day: Day?,
    val showCompleted: Boolean,
    val expandedSections: Set<DaySection>,
) {
    val context: DayContext = DayContext(date, now)

    /** Every non-canceled item: what progress counts and "next up" are computed from. */
    val raw: List<PlanItem> by lazy { items.excludingCanceled() }

    /** What the status filter lets onto the screen. */
    val visible: List<PlanItem> by lazy { items.matchingStatusFilter(showCompleted) }

    val sections: List<SectionModel> by lazy { DaySection.entries.map { context.sectionModel(it, visible, raw) } }

    /** Untimed, unsectioned items, shown in the "Open" card. */
    val openItems: List<PlanItem> by lazy { context.anyTimeItems(visible) }

    val progress: Progress by lazy { Progress.of(raw) }
    val nextUp: LocalTime? by lazy { context.nextUpcomingDeadline(raw) }
    val priorityCount: Int by lazy { context.outstandingFlaggedCount(raw) }

    val displayedFlightNumber: String get() = day?.displayFlightNumber ?: Day.defaultFlightNumber(date)
}

/** Drives the Cockpit tab: the selected day, its items, and the actions on them. */
class CockpitViewModel(
    private val repository: PlanRepository,
    private val clock: Clock = Clock.systemDefaultZone(),
    nowTicks: Flow<LocalDateTime> = minuteTicks(clock),
) : ViewModel() {

    private val selectedDate = MutableStateFlow(LocalDate.now(clock))
    private val showCompleted = MutableStateFlow(false)

    /** The user's manual expand/collapse choices for one date; reset whenever the date changes. */
    private val expandedOverride = MutableStateFlow<Pair<LocalDate, Set<DaySection>>?>(null)

    private data class DayData(val date: LocalDate, val items: List<PlanItem>, val day: Day?)

    @OptIn(ExperimentalCoroutinesApi::class)
    private val dayData: Flow<DayData> = selectedDate.flatMapLatest { date ->
        combine(repository.observeItems(date), repository.observeDay(date)) { items, day ->
            DayData(date, items, day)
        }
    }

    /** Null until the first read from the database completes. */
    val uiState: StateFlow<CockpitUiState?> = combine(
        dayData, nowTicks, showCompleted, expandedOverride,
    ) { data, now, showDone, override ->
        CockpitUiState(
            date = data.date,
            now = now,
            items = data.items,
            day = data.day,
            showCompleted = showDone,
            // Keyed by date so a stale override from another day can never leak onto this one.
            expandedSections = override?.takeIf { it.first == data.date }?.second
                ?: defaultExpanded(data.date, now),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    // region Item form

    private val _formTarget = MutableStateFlow<ItemFormTarget?>(null)

    /** The add/edit form currently open, if any. It lives here so it survives rotation. */
    val formTarget: StateFlow<ItemFormTarget?> = _formTarget.asStateFlow()

    /** Opens a blank form for the selected day, optionally preset to [section]. */
    fun openNewItemForm(section: DaySection? = null) {
        _formTarget.value = ItemFormTarget.New(selectedDate.value, section)
    }

    fun openEditForm(item: PlanItem) {
        _formTarget.value = ItemFormTarget.Edit(item)
    }

    fun dismissForm() {
        _formTarget.value = null
    }

    /** Saves [form] as a new item or as an edit of the open item, then closes the form. A blank title saves nothing. */
    fun saveItem(form: ItemFormState) {
        val target = _formTarget.value ?: return
        val existing = (target as? ItemFormTarget.Edit)?.item
        val item = form.toPlanItem(existing) ?: return
        _formTarget.value = null
        launch { if (existing == null) repository.addItem(item) else repository.updateItem(item) }
    }

    // endregion

    // region Date navigation

    fun goToYesterday() = navigate(selectedDate.value.minusDays(1))

    fun goToTomorrow() = navigate(selectedDate.value.plusDays(1))

    fun goToToday() = navigate(LocalDate.now(clock))

    fun navigate(date: LocalDate) {
        if (date == selectedDate.value) return
        selectedDate.value = date
        expandedOverride.value = null
    }

    // endregion

    // region View state

    fun toggleSection(section: DaySection) {
        val state = uiState.value ?: return
        val updated = if (section in state.expandedSections) state.expandedSections - section else state.expandedSections + section
        expandedOverride.value = state.date to updated
    }

    fun toggleShowCompleted() {
        showCompleted.value = !showCompleted.value
    }

    // endregion

    // region Item actions

    fun complete(item: PlanItem) = launch { repository.setStatus(item, ItemStatus.Completed) }

    /** Completed items go back to pending; anything else becomes completed. */
    fun toggleCompleted(item: PlanItem) = launch {
        repository.setStatus(item, if (item.status == ItemStatus.Completed) ItemStatus.Pending else ItemStatus.Completed)
    }

    fun cancel(item: PlanItem) = launch { repository.setStatus(item, ItemStatus.Canceled) }

    fun toggleFlag(item: PlanItem) = launch { repository.toggleFlag(item) }

    fun deferToTomorrow(item: PlanItem) = launch { repository.deferToTomorrow(item) }

    // endregion

    // region Day details

    fun setFlightName(text: String) {
        val date = selectedDate.value
        launch { repository.setFlightName(date, text) }
    }

    fun setIntention(text: String) {
        val date = selectedDate.value
        launch { repository.setIntention(date, text) }
    }

    // endregion

    private fun launch(block: suspend () -> Unit) {
        viewModelScope.launch { block() }
    }

    /** Today opens with its current section expanded; every other day opens fully collapsed. */
    private fun defaultExpanded(date: LocalDate, now: LocalDateTime): Set<DaySection> {
        val current = DayContext(date, now).currentSection
        return if (current != null) setOf(current) else emptySet()
    }
}

/** Emits the current time immediately, then again at the start of every minute. */
fun minuteTicks(clock: Clock): Flow<LocalDateTime> = flow {
    while (true) {
        val now = LocalDateTime.now(clock)
        emit(now)
        val nextMinute = now.truncatedTo(ChronoUnit.MINUTES).plusMinutes(1)
        delay(maxOf(1L, Duration.between(now, nextMinute).toMillis()))
    }
}
