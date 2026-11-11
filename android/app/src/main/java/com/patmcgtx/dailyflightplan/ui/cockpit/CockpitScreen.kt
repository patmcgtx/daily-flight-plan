package com.patmcgtx.dailyflightplan.ui.cockpit

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.GpsFixed
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.ui.form.ItemFormSheet
import com.patmcgtx.dailyflightplan.ui.form.PaperDatePickerDialog
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTheme

/** Everything the Cockpit screen can ask for, so [CockpitContent] stays free of the view model. */
data class CockpitActions(
    val onPreviousDay: () -> Unit = {},
    val onNextDay: () -> Unit = {},
    val onToday: () -> Unit = {},
    val onPickDate: (LocalDate) -> Unit = {},
    val onToggleShowCompleted: () -> Unit = {},
    val onToggleSection: (DaySection) -> Unit = {},
    val onFlightNameChange: (String) -> Unit = {},
    val onIntentionChange: (String) -> Unit = {},
    /** Opens a blank form; the section presets its segment (null means Open). */
    val onAddItem: (DaySection?) -> Unit = {},
    val items: ItemActions = ItemActions(),
)

/** The Cockpit tab: today's flight plan, with day navigation. */
@Composable
fun CockpitScreen(viewModel: CockpitViewModel, modifier: Modifier = Modifier) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val formTarget by viewModel.formTarget.collectAsStateWithLifecycle()
    val actions = remember(viewModel) {
        CockpitActions(
            onPreviousDay = viewModel::goToYesterday,
            onNextDay = viewModel::goToTomorrow,
            onToday = viewModel::goToToday,
            onPickDate = viewModel::navigate,
            onToggleShowCompleted = viewModel::toggleShowCompleted,
            onToggleSection = viewModel::toggleSection,
            onFlightNameChange = viewModel::setFlightName,
            onIntentionChange = viewModel::setIntention,
            onAddItem = viewModel::openNewItemForm,
            items = ItemActions(
                onOpen = viewModel::openEditForm,
                onComplete = viewModel::complete,
                onToggleCompleted = viewModel::toggleCompleted,
                onToggleFlag = viewModel::toggleFlag,
                onCancel = viewModel::cancel,
                onDefer = viewModel::deferToTomorrow,
            ),
        )
    }

    val current = state
    if (current == null) {
        // First read from the database hasn't landed yet: just the paper.
        Box(modifier.fillMaxSize().background(CockpitStyle.colors.background))
    } else {
        CockpitContent(current, actions, modifier)
        formTarget?.let { target ->
            ItemFormSheet(
                target = target,
                defaultTime = current.now.toLocalTime().truncatedTo(ChronoUnit.MINUTES),
                onSave = viewModel::saveItem,
                onDismiss = viewModel::dismissForm,
            )
        }
    }
}

/** The stateless Cockpit layout: a small action row above one scrolling column of cards. */
@Composable
fun CockpitContent(state: CockpitUiState, actions: CockpitActions, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    Box(modifier.fillMaxSize().background(colors.background)) {
        Column(Modifier.fillMaxSize()) {
            TopActions(state, actions)
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .imePadding(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // Cards stay a readable width on tablets and in landscape instead of stretching edge to edge.
                Column(
                    Modifier.widthIn(max = 640.dp).fillMaxWidth().padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    DayLabel(state.date, state.context.relativeDay, actions.onPreviousDay, actions.onNextDay)
                    FlightStatusCard(state, actions.onFlightNameChange, actions.onIntentionChange)
                    BriefingRow(state)
                    if (state.raw.isEmpty()) EmptyDayHint()
                    state.sections.forEach { model ->
                        SectionCard(
                            model = model,
                            expanded = model.section in state.expandedSections,
                            onToggle = { actions.onToggleSection(model.section) },
                            onAddItem = { actions.onAddItem(model.section) },
                            actions = actions.items,
                        )
                    }
                    if (state.openItems.isNotEmpty()) {
                        OpenCard(state.openItems, onAddItem = { actions.onAddItem(null) }, actions = actions.items)
                    }
                    // Room so the last card can scroll clear of the add button.
                    Spacer(Modifier.height(88.dp))
                }
            }
        }
        AddItemButton(
            onClick = { actions.onAddItem(null) },
            modifier = Modifier.align(Alignment.BottomEnd).padding(end = 20.dp, bottom = 20.dp),
        )
    }
}

/** The floating "+": a square highlighter-yellow key with a hard shadow, like everything else here. */
@Composable
private fun AddItemButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(56.dp)
            .paperCard(fill = CockpitStyle.colors.highlighter)
            .clickable(role = Role.Button, onClickLabel = "Add item", onClick = onClick)
            .semantics { contentDescription = "Add item" },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Outlined.Add, contentDescription = null, tint = CockpitStyle.inkOnHighlighter)
    }
}

/** Go-to-today (when away from today) and the show-completed toggle. */
@Composable
private fun TopActions(state: CockpitUiState, actions: CockpitActions) {
    val colors = CockpitStyle.colors
    var showDatePicker by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = { showDatePicker = true }) {
            Icon(Icons.Outlined.CalendarMonth, contentDescription = "Pick a date", tint = colors.ink)
        }
        if (!state.context.isToday) {
            IconButton(onClick = actions.onToday) {
                Icon(Icons.Outlined.GpsFixed, contentDescription = "Go to today", tint = colors.ink)
            }
        }
        IconButton(onClick = actions.onToggleShowCompleted) {
            Icon(
                imageVector = if (state.showCompleted) Icons.Outlined.Visibility else Icons.Outlined.VisibilityOff,
                contentDescription = if (state.showCompleted) "Hide completed items" else "Show completed items",
                tint = if (state.showCompleted) colors.ink else colors.muted,
            )
        }
    }
    if (showDatePicker) {
        PaperDatePickerDialog(
            initial = state.date,
            onConfirm = { actions.onPickDate(it); showDatePicker = false },
            onDismiss = { showDatePicker = false },
        )
    }
}

/** Shown on a day with nothing on it yet, pointing at the way to add the first item. */
@Composable
private fun EmptyDayHint() {
    Text(
        text = "Nothing on this flight plan yet. Tap + to add your first item.",
        style = CockpitStyle.mono(CockpitTextStyle.Subheadline),
        color = CockpitStyle.colors.muted,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
    )
}

@Preview(name = "Light", showBackground = true, heightDp = 1600)
@Preview(name = "Dark", showBackground = true, heightDp = 1600, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun CockpitPreview() {
    CockpitTheme {
        CockpitContent(SampleData.state(), CockpitActions())
    }
}
