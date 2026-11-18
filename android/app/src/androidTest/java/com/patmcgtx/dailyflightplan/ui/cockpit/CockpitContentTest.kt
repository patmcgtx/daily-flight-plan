package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.hasAnyChild
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTheme
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/**
 * Compose UI tests for the Cockpit screen: what a screen reader is told, and that touch targets are
 * big enough. Method names are camelCase sentences (backticked names with spaces aren't allowed in
 * instrumented tests below minSdk 30).
 */
class CockpitContentTest {

    @get:Rule
    val rule = createComposeRule()

    private val sample = SampleData.state()
    private val allExpanded = sample.copy(expandedSections = DaySection.entries.toSet())

    private fun show(state: CockpitUiState = allExpanded, actions: CockpitActions = CockpitActions()) {
        rule.setContent { CockpitTheme { CockpitContent(state, actions) } }
    }

    private fun stateDescription(value: String) =
        SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, value)

    // region Screen-reader semantics

    @Test
    fun sectionHeadersReadAsButtonsWithTheirProgressAndExpandedState() {
        show(sample) // Midday and Afternoon expanded, the rest collapsed
        rule.onNode(hasContentDescription("Morning, 7:30 – 11 AM, 1 of 3 done, overdue, has flagged items"))
            .assert(stateDescription("Collapsed"))
            .assertHasClickAction()
        rule.onNode(hasContentDescription("Midday", substring = true) and hasClickAction())
            .assert(stateDescription("Expanded"))
    }

    @Test
    fun theCurrentSectionIsAnnouncedAsCurrent() {
        // 12:00 on the sample day is Midday.
        show(sample)
        rule.onNode(hasContentDescription("current section", substring = true)).assertExists()
    }

    @Test
    fun flaggedAndMissedItemsAreSpokenNotJustColored() {
        show()
        assertTrue(rule.onAllNodes(stateDescription("Flagged")).fetchSemanticsNodes().size >= 2) // Review PRs and Dentist
        rule.onNode(stateDescription("Missed")).assertExists() // Standup, 9:30 AM, with the clock at noon
    }

    @Test
    fun theDayHeadingIsAHeadingSpokenAsAFullDate() {
        show()
        rule.onNode(
            SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading) and
                hasContentDescription("2026", substring = true) and
                hasContentDescription("today", substring = true),
        ).assertExists()
    }

    @Test
    fun itemRowsOfferTheLongPressActionsAsScreenReaderActions() {
        var flagged: PlanItem? = null
        show(actions = CockpitActions(items = ItemActions(onToggleFlag = { flagged = it })))
        val node = rule.onNode(hasText("REVIEW PRS")).fetchSemanticsNode()
        val custom = node.config.getOrNull(SemanticsActions.CustomActions).orEmpty()
        assertEquals(listOf("Complete", "Remove flag", "Cancel item", "Defer to tomorrow"), custom.map { it.label })
        assertTrue(custom.first { it.label == "Remove flag" }.action())
        assertEquals("Review PRs", flagged?.title)
    }

    @Test
    fun timedRowsOfferTheirActionsToo() {
        show()
        val node = rule.onNode(hasText("STANDUP")).fetchSemanticsNode()
        val labels = node.config.getOrNull(SemanticsActions.CustomActions).orEmpty().map { it.label }
        assertEquals(listOf("Complete", "Flag", "Cancel item"), labels) // timed items can't be deferred, as on iOS
    }

    @Test
    fun theProgressBoxIsSpokenInWords() {
        show()
        rule.onNode(hasContentDescription("Flight progress, ", substring = true)).assertExists()
    }

    // endregion

    // region Actions

    @Test
    fun tappingACompleteCircleCompletesThatItem() {
        var completed: PlanItem? = null
        show(actions = CockpitActions(items = ItemActions(onComplete = { completed = it })))
        rule.onNode(
            hasClickAction() and hasAnyChild(hasContentDescription("Complete Review PRs")),
            useUnmergedTree = true,
        ).performClick()
        assertEquals("Review PRs", completed?.title)
    }

    @Test
    fun tappingASectionHeaderTogglesThatSection() {
        var toggled: DaySection? = null
        show(sample, CockpitActions(onToggleSection = { toggled = it }))
        rule.onNode(hasContentDescription("Morning", substring = true) and hasClickAction()).performClick()
        assertEquals(DaySection.Morning, toggled)
    }

    @Test
    fun theAddButtonAndEachCardsAddLinkOpenTheForm() {
        val requested = mutableListOf<DaySection?>()
        show(actions = CockpitActions(onAddItem = { requested += it }))
        rule.onNode(hasContentDescription("Add item") and hasClickAction()).performClick()
        rule.onAllNodes(hasText("ADD ITEM")).onFirst().performClick()
        assertEquals(listOf(null, DaySection.FirstThing), requested)
    }

    @Test
    fun dayArrowsStepOneDayEachWay() {
        var back = 0
        var forward = 0
        show(actions = CockpitActions(onPreviousDay = { back++ }, onNextDay = { forward++ }))
        rule.onNodeWithContentDescription("Previous day").performClick()
        rule.onNodeWithContentDescription("Next day").performClick()
        rule.onNodeWithContentDescription("Next day").performClick()
        assertEquals(1, back)
        assertEquals(2, forward)
    }

    @Test
    fun theDatePickerOpensFromTheTopBarAndReportsTheChosenDay() {
        var picked: LocalDate? = null
        show(actions = CockpitActions(onPickDate = { picked = it }))
        rule.onNodeWithContentDescription("Pick a date").performClick()
        rule.onNodeWithText("OK").performClick()
        assertEquals(sample.date, picked)
    }

    // endregion

    // region Empty states

    @Test
    fun anEmptyDayPointsAtTheAddButton() {
        show(allExpanded.copy(items = emptyList()))
        rule.onNode(hasText("Tap + to add your first item.", substring = true)).assertExists()
    }

    @Test
    fun aDayWithItemsDoesNotShowTheEmptyHint() {
        show()
        rule.onNode(hasText("Tap + to add your first item.", substring = true)).assertDoesNotExist()
    }

    @Test
    fun aFinishedSectionWithHiddenCompletedItemsSaysSoInsteadOfNothingScheduled() {
        val done = PlanItem(id = 1, title = "Stretch", date = sample.date, daySection = DaySection.Evening, status = ItemStatus.Completed)
        show(allExpanded.copy(items = listOf(done)))
        rule.onNode(hasText("Completed items are hidden", substring = true)).assertExists()
    }

    // endregion

    // region Touch targets

    /**
     * The area that responds to touch. Compose already widens small tappable elements to 48dp for
     * hit-testing, so this holds for any tappable node; it is the platform's guarantee, used here
     * for Material's 40dp icon buttons. Controls we size ourselves are checked by layout size instead.
     */
    private fun SemanticsNodeInteraction.assertTouchBoundsAtLeast(minimum: Dp) {
        val bounds = fetchSemanticsNode().touchBoundsInRoot
        val density = rule.density.density
        val width = bounds.width / density
        val height = bounds.height / density
        assertTrue("touch area is ${width}x${height}dp, needs at least ${minimum.value}dp", width >= minimum.value - 0.5f && height >= minimum.value - 0.5f)
    }

    @Test
    fun theTopBarIconButtonsHaveA48dpTouchArea() {
        show()
        for (description in listOf("Pick a date", "Show completed items")) {
            rule.onNodeWithContentDescription(description).assertTouchBoundsAtLeast(48.dp)
        }
    }

    @Test
    fun theDayArrowsAndTheAddButtonAreAtLeast48dpSquare() {
        show()
        for (description in listOf("Previous day", "Next day")) {
            rule.onNodeWithContentDescription(description).assertWidthIsAtLeast(48.dp).assertHeightIsAtLeast(48.dp)
        }
        rule.onNode(hasContentDescription("Add item") and hasClickAction())
            .assertWidthIsAtLeast(48.dp).assertHeightIsAtLeast(48.dp)
    }

    @Test
    fun theCompleteCircleHasAtLeastA40dpTouchTarget() {
        show()
        rule.onNode(
            hasClickAction() and hasAnyChild(hasContentDescription("Complete Review PRs")),
            useUnmergedTree = true,
        ).assertWidthIsAtLeast(40.dp).assertHeightIsAtLeast(40.dp)
    }

    @Test
    fun theTimedRowCheckHasA48dpTouchTarget() {
        show()
        rule.onNode(hasContentDescription("Complete Standup") and hasClickAction(), useUnmergedTree = true)
            .assertWidthIsAtLeast(48.dp).assertHeightIsAtLeast(48.dp)
    }

    // endregion
}
