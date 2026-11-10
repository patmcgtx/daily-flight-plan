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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.GpsFixed
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTheme

/** Everything the Cockpit screen can ask for, so [CockpitContent] stays free of the view model. */
data class CockpitActions(
    val onPreviousDay: () -> Unit = {},
    val onNextDay: () -> Unit = {},
    val onToday: () -> Unit = {},
    val onToggleShowCompleted: () -> Unit = {},
    val onToggleSection: (DaySection) -> Unit = {},
    val onFlightNameChange: (String) -> Unit = {},
    val onIntentionChange: (String) -> Unit = {},
    val items: ItemActions = ItemActions(),
)

/** The Cockpit tab: today's flight plan, with day navigation. */
@Composable
fun CockpitScreen(viewModel: CockpitViewModel, modifier: Modifier = Modifier) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val actions = remember(viewModel) {
        CockpitActions(
            onPreviousDay = viewModel::goToYesterday,
            onNextDay = viewModel::goToTomorrow,
            onToday = viewModel::goToToday,
            onToggleShowCompleted = viewModel::toggleShowCompleted,
            onToggleSection = viewModel::toggleSection,
            onFlightNameChange = viewModel::setFlightName,
            onIntentionChange = viewModel::setIntention,
            items = ItemActions(
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
    }
}

/** The stateless Cockpit layout: a small action row above one scrolling column of cards. */
@Composable
fun CockpitContent(state: CockpitUiState, actions: CockpitActions, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    Column(modifier.fillMaxSize().background(colors.background)) {
        TopActions(state, actions)
        Column(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            DayLabel(state.date, state.context.relativeDay, actions.onPreviousDay, actions.onNextDay)
            FlightStatusCard(state, actions.onFlightNameChange, actions.onIntentionChange)
            BriefingRow(state)
            state.sections.forEach { model ->
                SectionCard(
                    model = model,
                    expanded = model.section in state.expandedSections,
                    onToggle = { actions.onToggleSection(model.section) },
                    actions = actions.items,
                )
            }
            if (state.openItems.isNotEmpty()) {
                OpenCard(state.openItems, actions.items)
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}

/** Go-to-today (when away from today) and the show-completed toggle. */
@Composable
private fun TopActions(state: CockpitUiState, actions: CockpitActions) {
    val colors = CockpitStyle.colors
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically,
    ) {
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
}

@Preview(name = "Light", showBackground = true, heightDp = 1600)
@Preview(name = "Dark", showBackground = true, heightDp = 1600, uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun CockpitPreview() {
    CockpitTheme {
        CockpitContent(SampleData.state(), CockpitActions())
    }
}
