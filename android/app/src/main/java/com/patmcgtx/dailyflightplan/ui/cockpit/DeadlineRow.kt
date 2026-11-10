package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

private val timeFormatter: DateTimeFormatter = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)

/** A time of day in the user's locale, e.g. "2:30 PM". */
fun LocalTime.formatShort(): String = format(timeFormatter)

/** A timed item: a full-width row with a round check button, the title, and its clock time. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun DeadlineRow(item: PlanItem, actions: ItemActions, isMissed: Boolean, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    var menuOpen by remember { mutableStateOf(false) }
    val completed = item.status == ItemStatus.Completed
    val (titleColor, titleHighlight) = itemTitleColors(item)

    Box(modifier) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .combinedClickable(
                    onClick = { actions.onOpen(item) },
                    onLongClick = { menuOpen = true },
                )
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            val checkColor = if (completed) colors.routeBlue else colors.border.copy(alpha = 0.5f)
            Box(
                modifier = Modifier
                    .size(26.dp)
                    .clip(CircleShape)
                    .border(1.5.dp, checkColor, CircleShape)
                    .clickable(role = Role.Checkbox) { actions.onToggleCompleted(item) }
                    .semantics {
                        contentDescription =
                            if (completed) "Mark ${item.title} as not complete" else "Complete ${item.title}"
                    },
                contentAlignment = Alignment.Center,
            ) {
                if (completed) {
                    Icon(Icons.Filled.Check, contentDescription = null, tint = colors.routeBlue, modifier = Modifier.size(14.dp))
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(3.dp), modifier = Modifier.weight(1f)) {
                Text(
                    text = item.title.uppercase(),
                    style = CockpitStyle.mono(CockpitTextStyle.Body, FontWeight.SemiBold),
                    color = titleColor,
                    textDecoration = if (completed) TextDecoration.LineThrough else null,
                    modifier = titleHighlight,
                )
                item.deadline?.let { time ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                        val timeColor = if (isMissed) PaperAccents.overdue else colors.muted
                        Icon(Icons.Outlined.Schedule, contentDescription = null, tint = timeColor, modifier = Modifier.size(12.dp))
                        Text(
                            text = time.formatShort() + if (isMissed) " · MISSED" else "",
                            style = CockpitStyle.mono(CockpitTextStyle.Caption2, if (isMissed) FontWeight.Bold else FontWeight.Normal),
                            color = timeColor,
                        )
                    }
                }
            }
        }
        ItemContextMenu(menuOpen, { menuOpen = false }, item, actions, allowDefer = false)
    }
}
