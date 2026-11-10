package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.RelativeDay
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/** The big weekday heading flanked by ← / → buttons that step a day at a time. */
@Composable
fun DayLabel(
    date: LocalDate,
    relativeDay: RelativeDay?,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = CockpitStyle.colors
    Row(
        modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        DayArrowButton(Icons.Filled.ChevronLeft, "Previous day", onPrevious)
        Column(
            Modifier.weight(1f),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                val monthDay = "${date.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())} ${date.dayOfMonth}"
                Text(monthDay.uppercase(), style = CockpitStyle.mono(CockpitTextStyle.Subheadline), color = colors.muted)
                when (relativeDay) {
                    RelativeDay.Today -> Text(
                        "TODAY",
                        style = CockpitStyle.mono(CockpitTextStyle.Caption, FontWeight.Bold),
                        color = CockpitStyle.inkOnHighlighter,
                        modifier = Modifier.background(colors.highlighter).padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                    RelativeDay.Tomorrow, RelativeDay.Yesterday -> Text(
                        relativeDay.name.uppercase(),
                        style = CockpitStyle.mono(CockpitTextStyle.Caption, FontWeight.Bold),
                        color = colors.muted,
                    )
                    null -> Unit
                }
            }
            Text(
                text = date.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault()).uppercase(),
                style = CockpitStyle.mono(CockpitTextStyle.LargeTitle, FontWeight.Bold),
                color = colors.ink,
            )
        }
        DayArrowButton(Icons.Filled.ChevronRight, "Next day", onNext)
    }
}

@Composable
private fun DayArrowButton(icon: ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(40.dp)
            .paperCard(shadowOffset = DpOffset(2.dp, 3.dp))
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = description, tint = CockpitStyle.colors.ink)
    }
}
