package com.patmcgtx.dailyflightplan.ui.cockpit

import com.patmcgtx.dailyflightplan.data.FakeDayDao
import com.patmcgtx.dailyflightplan.data.FakePlanItemDao
import com.patmcgtx.dailyflightplan.data.PlanRepository
import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemFormState
import com.patmcgtx.dailyflightplan.model.ItemFormTarget
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneOffset
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

/** The clock is fixed at noon on 2026-06-15 and ticks are injected, so nothing here reads real time. */
@OptIn(ExperimentalCoroutinesApi::class)
class CockpitViewModelTest {

    private val today = LocalDate.of(2026, 6, 15)
    private val tomorrow = today.plusDays(1)
    private val clock = Clock.fixed(Instant.parse("2026-06-15T12:00:00Z"), ZoneOffset.UTC)
    private val ticks = MutableSharedFlow<LocalDateTime>(replay = 1)
    private val itemDao = FakePlanItemDao()
    private val dayDao = FakeDayDao()

    @BeforeEach
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        ticks.tryEmit(LocalDateTime.of(today, LocalTime.NOON))
    }

    @AfterEach
    fun tearDown() = Dispatchers.resetMain()

    /** A view model with a live subscriber, so `uiState.value` is current after every action. */
    private fun TestScope.viewModel(): CockpitViewModel {
        val viewModel = CockpitViewModel(PlanRepository(itemDao, dayDao), clock, ticks)
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect {} }
        return viewModel
    }

    private suspend fun add(
        title: String = "Item",
        date: LocalDate = today,
        daySection: DaySection? = null,
        status: ItemStatus = ItemStatus.Pending,
    ): PlanItem {
        val id = itemDao.insert(PlanItem(title = title, date = date, daySection = daySection, status = status))
        return itemDao.get(id)!!
    }

    private fun CockpitViewModel.state() = uiState.value!!

    // region Initial state

    @Test
    fun `The first state is today with its current section expanded and the default flight number`() = runTest {
        val state = viewModel().state()
        assertEquals(today, state.date)
        assertEquals(LocalDateTime.of(today, LocalTime.NOON), state.now)
        assertEquals(setOf(DaySection.Midday), state.expandedSections)
        assertEquals("DFP 20260615", state.displayedFlightNumber)
        assertEquals(false, state.showCompleted)
    }

    @Test
    fun `The state shows only the selected day's items`() = runTest {
        val todays = add("Today")
        add("Tomorrow", date = tomorrow)
        assertEquals(listOf(todays.id), viewModel().state().items.map { it.id })
    }

    @Test
    fun `A stored day supplies the displayed flight name and destination`() = runTest {
        dayDao.upsert(Day(today, flightName = "Deep Work", intention = "Ship it"))
        val state = viewModel().state()
        assertEquals("Deep Work", state.displayedFlightNumber)
        assertEquals("Ship it", state.day?.intention)
    }

    // endregion

    // region Date navigation

    @Test
    fun `goToTomorrow and goToYesterday move one day and show that day's items`() = runTest {
        val viewModel = viewModel()
        val tomorrowItem = add("Tomorrow", date = tomorrow)
        val yesterdayItem = add("Yesterday", date = today.minusDays(1))

        viewModel.goToTomorrow()
        assertEquals(tomorrow, viewModel.state().date)
        assertEquals(listOf(tomorrowItem.id), viewModel.state().items.map { it.id })

        viewModel.goToYesterday()
        viewModel.goToYesterday()
        assertEquals(today.minusDays(1), viewModel.state().date)
        assertEquals(listOf(yesterdayItem.id), viewModel.state().items.map { it.id })
    }

    @Test
    fun `goToToday returns to the current day from anywhere`() = runTest {
        val viewModel = viewModel()
        viewModel.navigate(today.plusDays(30))
        viewModel.goToToday()
        assertEquals(today, viewModel.state().date)
    }

    @Test
    fun `Days other than today open fully collapsed`() = runTest {
        val viewModel = viewModel()
        viewModel.goToTomorrow()
        assertEquals(emptySet<DaySection>(), viewModel.state().expandedSections)
    }

    @Test
    fun `The state's context reports tomorrow as a different day than now`() = runTest {
        val viewModel = viewModel()
        viewModel.goToTomorrow()
        assertEquals(false, viewModel.state().context.isToday)
        assertNull(viewModel.state().context.currentSection)
    }

    // endregion

    // region Expanded sections

    @Test
    fun `toggleSection collapses and re-expands a section`() = runTest {
        val viewModel = viewModel()
        viewModel.toggleSection(DaySection.Midday)
        assertEquals(emptySet<DaySection>(), viewModel.state().expandedSections)
        viewModel.toggleSection(DaySection.Midday)
        assertEquals(setOf(DaySection.Midday), viewModel.state().expandedSections)
    }

    @Test
    fun `toggleSection can expand several sections at once`() = runTest {
        val viewModel = viewModel()
        viewModel.toggleSection(DaySection.Morning)
        assertEquals(setOf(DaySection.Midday, DaySection.Morning), viewModel.state().expandedSections)
    }

    @Test
    fun `Changing the date resets manual expand and collapse choices`() = runTest {
        val viewModel = viewModel()
        viewModel.toggleSection(DaySection.Morning)
        viewModel.goToTomorrow()
        viewModel.goToToday()
        assertEquals(setOf(DaySection.Midday), viewModel.state().expandedSections)
    }

    @Test
    fun `Navigating to the date already shown keeps manual choices`() = runTest {
        val viewModel = viewModel()
        viewModel.toggleSection(DaySection.Morning)
        viewModel.navigate(today)
        assertEquals(setOf(DaySection.Midday, DaySection.Morning), viewModel.state().expandedSections)
    }

    @Test
    fun `The minute tick moves an untouched expansion to the new current section`() = runTest {
        val viewModel = viewModel()
        ticks.emit(LocalDateTime.of(today, LocalTime.of(14, 0)))
        assertEquals(LocalTime.of(14, 0), viewModel.state().now.toLocalTime())
        assertEquals(setOf(DaySection.Afternoon), viewModel.state().expandedSections)
    }

    @Test
    fun `The minute tick leaves manual choices alone`() = runTest {
        val viewModel = viewModel()
        viewModel.toggleSection(DaySection.Midday)
        ticks.emit(LocalDateTime.of(today, LocalTime.of(14, 0)))
        assertEquals(emptySet<DaySection>(), viewModel.state().expandedSections)
    }

    // endregion

    // region Status filter

    @Test
    fun `Completed items are hidden until completed items are revealed`() = runTest {
        val viewModel = viewModel()
        val pending = add("Pending")
        val done = add("Done", status = ItemStatus.Completed)
        val canceled = add("Canceled", status = ItemStatus.Canceled)

        assertEquals(listOf(pending.id), viewModel.state().visible.map { it.id })
        // Progress still counts the completed item, but never the canceled one.
        assertEquals(listOf(pending.id, done.id), viewModel.state().raw.map { it.id })

        viewModel.toggleShowCompleted()
        assertEquals(setOf(pending.id, done.id, canceled.id), viewModel.state().visible.map { it.id }.toSet())

        viewModel.toggleShowCompleted()
        assertEquals(listOf(pending.id), viewModel.state().visible.map { it.id })
    }

    // endregion

    // region Item actions

    @Test
    fun `complete marks an item completed and toggleCompleted can undo it`() = runTest {
        val viewModel = viewModel()
        val item = add()
        viewModel.toggleShowCompleted()

        viewModel.complete(item)
        assertEquals(ItemStatus.Completed, itemDao.get(item.id)!!.status)
        viewModel.toggleCompleted(itemDao.get(item.id)!!)
        assertEquals(ItemStatus.Pending, itemDao.get(item.id)!!.status)
        viewModel.toggleCompleted(itemDao.get(item.id)!!)
        assertEquals(ItemStatus.Completed, itemDao.get(item.id)!!.status)
    }

    @Test
    fun `cancel marks an item canceled and removes it from progress`() = runTest {
        val viewModel = viewModel()
        val item = add()
        viewModel.cancel(item)
        assertEquals(ItemStatus.Canceled, itemDao.get(item.id)!!.status)
        assertEquals(0, viewModel.state().progress.total)
    }

    @Test
    fun `toggleFlag flips an item's flag and is reflected in the priority count`() = runTest {
        val viewModel = viewModel()
        val item = add()
        viewModel.toggleFlag(item)
        assertEquals(1, viewModel.state().priorityCount)
        viewModel.toggleFlag(itemDao.get(item.id)!!)
        assertEquals(0, viewModel.state().priorityCount)
    }

    @Test
    fun `deferToTomorrow moves an item off today and onto tomorrow`() = runTest {
        val viewModel = viewModel()
        val item = add()
        viewModel.deferToTomorrow(item)

        assertEquals(emptyList<Long>(), viewModel.state().items.map { it.id })
        viewModel.goToTomorrow()
        assertEquals(listOf(item.id), viewModel.state().items.map { it.id })
    }

    @Test
    fun `Progress counts completed items among today's non-canceled items`() = runTest {
        val viewModel = viewModel()
        add("A", status = ItemStatus.Completed)
        add("B")
        add("C", status = ItemStatus.Canceled)
        assertEquals(1, viewModel.state().progress.completed)
        assertEquals(2, viewModel.state().progress.total)
    }

    // endregion

    // region Item form

    private fun CockpitViewModel.blankForm(date: LocalDate = today) =
        ItemFormState.forNew(date, defaultTime = LocalTime.of(9, 0))

    @Test
    fun `No form is open at first`() = runTest {
        assertNull(viewModel().formTarget.value)
    }

    @Test
    fun `openNewItemForm targets the selected day and the given section`() = runTest {
        val viewModel = viewModel()
        viewModel.goToTomorrow()
        viewModel.openNewItemForm(DaySection.Evening)
        assertEquals(ItemFormTarget.New(tomorrow, DaySection.Evening), viewModel.formTarget.value)
        viewModel.openNewItemForm()
        assertEquals(ItemFormTarget.New(tomorrow, null), viewModel.formTarget.value)
    }

    @Test
    fun `openEditForm targets the item and dismissForm closes it`() = runTest {
        val viewModel = viewModel()
        val item = add()
        viewModel.openEditForm(item)
        assertEquals(ItemFormTarget.Edit(item), viewModel.formTarget.value)
        viewModel.dismissForm()
        assertNull(viewModel.formTarget.value)
    }

    @Test
    fun `Saving a new form adds the item and closes the form`() = runTest {
        val viewModel = viewModel()
        viewModel.openNewItemForm(DaySection.Evening)
        viewModel.saveItem(viewModel.blankForm().copy(title = "  Cook  ", daySection = DaySection.Evening))

        assertNull(viewModel.formTarget.value)
        val saved = viewModel.state().items.single()
        assertEquals("Cook", saved.title)
        assertEquals(DaySection.Evening, saved.daySection)
        assertEquals(today, saved.date)
    }

    @Test
    fun `Saving a new form with another date puts the item on that day`() = runTest {
        val viewModel = viewModel()
        viewModel.openNewItemForm()
        viewModel.saveItem(viewModel.blankForm(date = tomorrow).copy(title = "Later"))

        assertEquals(emptyList<PlanItem>(), viewModel.state().items)
        viewModel.goToTomorrow()
        assertEquals("Later", viewModel.state().items.single().title)
    }

    @Test
    fun `Saving an edit updates the item in place and keeps its status`() = runTest {
        val viewModel = viewModel()
        val item = add("Old", status = ItemStatus.Completed)
        viewModel.openEditForm(item)
        viewModel.saveItem(ItemFormState.from(item, LocalTime.NOON).copy(title = "New", isFlagged = true))

        assertNull(viewModel.formTarget.value)
        assertEquals(1, itemDao.all.size)
        assertEquals(item.copy(title = "New", isFlagged = true), itemDao.get(item.id))
    }

    @Test
    fun `Saving a blank title saves nothing and leaves the form open`() = runTest {
        val viewModel = viewModel()
        viewModel.openNewItemForm()
        viewModel.saveItem(viewModel.blankForm().copy(title = "   "))

        assertEquals(emptyList<PlanItem>(), itemDao.all)
        assertEquals(ItemFormTarget.New(today, null), viewModel.formTarget.value)
    }

    @Test
    fun `Saving with no form open does nothing`() = runTest {
        val viewModel = viewModel()
        viewModel.saveItem(viewModel.blankForm().copy(title = "Orphan"))
        assertEquals(emptyList<PlanItem>(), itemDao.all)
    }

    // endregion

    // region Day details

    @Test
    fun `setFlightName and setIntention write to the day currently shown`() = runTest {
        val viewModel = viewModel()
        viewModel.goToTomorrow()
        viewModel.setFlightName("Deep Work")
        viewModel.setIntention("Rest up")

        assertNull(dayDao.all[today])
        assertEquals(Day(tomorrow, "Deep Work", "Rest up"), dayDao.all[tomorrow])
        assertEquals("Deep Work", viewModel.state().displayedFlightNumber)
    }

    @Test
    fun `Typing the default flight name back in leaves no stored day`() = runTest {
        val viewModel = viewModel()
        viewModel.setFlightName("Deep Work")
        assertNotNull(dayDao.all[today])
        viewModel.setFlightName("DFP 20260615")
        assertNull(dayDao.all[today])
    }

    // endregion
}
