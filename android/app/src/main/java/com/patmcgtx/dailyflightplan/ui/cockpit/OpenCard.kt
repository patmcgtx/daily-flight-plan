package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.PlanItem
import com.patmcgtx.dailyflightplan.model.Progress
import com.patmcgtx.dailyflightplan.model.spokenStatus

/** The "Open" card: items with no section and no time. Shown only when there's something in it. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OpenCard(items: List<PlanItem>, onAddItem: () -> Unit, actions: ItemActions, modifier: Modifier = Modifier) {
    Column(modifier.paperCard()) {
        CardHeader(
            title = "Open",
            subtitle = "no specific time",
            progress = Progress.of(items),
            isCurrent = false,
            hasOverdue = false,
            description = "Open, no specific time, ${Progress.of(items).spokenStatus()}",
        )
        PaperRule(alpha = 1f)
        AddItemLink(onAddItem)
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 14.dp),
        ) {
            items.forEach { ItemPill(it, actions) }
        }
    }
}
