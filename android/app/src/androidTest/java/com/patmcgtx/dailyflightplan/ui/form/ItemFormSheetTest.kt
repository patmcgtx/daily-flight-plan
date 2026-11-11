package com.patmcgtx.dailyflightplan.ui.form

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isToggleable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemFormState
import com.patmcgtx.dailyflightplan.model.ItemFormTarget
import com.patmcgtx.dailyflightplan.model.PlanItem
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTheme
import java.time.LocalDate
import java.time.LocalTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test

/** Compose UI tests for the add/edit sheet. (The form's saving rules are unit-tested in `ItemFormStateTest`.) */
class ItemFormSheetTest {

    @get:Rule
    val rule = createComposeRule()

    private val date = LocalDate.of(2026, 6, 15)

    private fun show(
        target: ItemFormTarget = ItemFormTarget.New(date, DaySection.Evening),
        onSave: (ItemFormState) -> Unit = {},
        onDismiss: () -> Unit = {},
    ) {
        rule.setContent { CockpitTheme { ItemFormSheet(target, LocalTime.of(9, 0), onSave, onDismiss) } }
    }

    @Test
    fun saveIsDisabledUntilATitleIsTyped() {
        show()
        rule.onNodeWithText("SAVE").assertIsNotEnabled()
        rule.onNodeWithContentDescription("Item title").performTextInput("Call mom")
        rule.onNodeWithText("SAVE").assertIsEnabled()
    }

    @Test
    fun savingHandsBackTheTypedTitleOnThePresetDayAndSection() {
        var saved: ItemFormState? = null
        show(onSave = { saved = it })
        rule.onNodeWithContentDescription("Item title").performTextInput("Call mom")
        rule.onNodeWithText("SAVE").performClick()

        assertEquals("Call mom", saved?.title)
        assertEquals(DaySection.Evening, saved?.daySection)
        assertEquals(date, saved?.date)
    }

    @Test
    fun cancelDismissesWithoutSaving() {
        var saved: ItemFormState? = null
        var dismissed = false
        show(onSave = { saved = it }, onDismiss = { dismissed = true })
        rule.onNodeWithContentDescription("Item title").performTextInput("Never saved")
        rule.onNodeWithText("CANCEL").performClick()

        assertEquals(true, dismissed)
        assertNull(saved)
    }

    @Test
    fun theSegmentChoicesAreSelectableAndTellAScreenReaderWhichIsSelected() {
        show()
        rule.onNodeWithText("EVENING").assertIsSelected()
        rule.onNodeWithText("OPEN").assertIsNotSelected()
        rule.onNodeWithText("MORNING").performClick()
        rule.onNodeWithText("MORNING").assertIsSelected()
        rule.onNodeWithText("EVENING").assertIsNotSelected()
    }

    @Test
    fun aSpecificTimeReplacesTheSegmentChoicesWithATimeRow() {
        show()
        rule.onNodeWithText("SEGMENT").assertExists()
        rule.onNode(hasContentDescription("Specific time") and isToggleable()).assertIsOff().performClick()

        rule.onNodeWithText("SEGMENT").assertDoesNotExist()
        rule.onNodeWithText("TIME").assertExists()
        rule.onNode(hasContentDescription("Specific time") and isToggleable()).assertIsOn()
    }

    @Test
    fun theFlaggedSwitchIsAToggleThatReportsItsState() {
        show()
        rule.onNode(hasContentDescription("Flagged") and isToggleable()).assertIsOff().performClick().assertIsOn()
    }

    @Test
    fun editingShowsTheItemsCurrentValuesAndSavesThemBack() {
        val item = PlanItem(id = 7, title = "Dentist", notes = "Bring forms", isFlagged = true, date = date, deadline = LocalTime.of(15, 45))
        var saved: ItemFormState? = null
        show(ItemFormTarget.Edit(item), onSave = { saved = it })

        rule.onNodeWithText("EDIT ITEM").assertExists()
        rule.onNodeWithContentDescription("Item title").assertTextEquals("Dentist")
        rule.onNodeWithContentDescription("Item notes").assertTextEquals("Bring forms")
        rule.onNode(hasContentDescription("Flagged") and isToggleable()).assertIsOn()
        rule.onNode(hasContentDescription("Specific time") and isToggleable()).assertIsOn()

        rule.onNodeWithText("SAVE").performClick()
        assertNotNull(saved)
        assertEquals(ItemFormState.from(item, LocalTime.of(9, 0)), saved)
    }

    @Test
    fun theTimePickerOpensFromItsRowAndConfirmingKeepsTheTime() {
        val item = PlanItem(id = 7, title = "T", date = date, deadline = LocalTime.of(15, 45))
        var saved: ItemFormState? = null
        show(ItemFormTarget.Edit(item), onSave = { saved = it })

        rule.onNode(hasText("TIME")).performClick()
        rule.onNodeWithText("OK").performClick() // confirm without changing anything
        rule.onNodeWithText("SAVE").performClick()

        assertEquals(LocalTime.of(15, 45), saved?.deadline)
    }

    @Test
    fun theDatePickerOpensFromItsRowAndConfirmingKeepsTheDate() {
        var saved: ItemFormState? = null
        show(onSave = { saved = it })

        rule.onNodeWithContentDescription("Item title").performTextInput("Call mom")
        rule.onNode(hasText("DATE")).performClick()
        rule.onNodeWithText("OK").performClick()
        rule.onNodeWithText("SAVE").performClick()

        assertEquals(date, saved?.date)
    }
}
