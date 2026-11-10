package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.HourglassBottom
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.Briefing
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.ZonedDateTime
import kotlinx.coroutines.delay

/** The real time, refreshed every second on the second boundary. */
@Composable
private fun rememberTickingTime(): State<ZonedDateTime> = produceState(ZonedDateTime.now()) {
    while (true) {
        value = ZonedDateTime.now()
        delay(1_000 - System.currentTimeMillis() % 1_000)
    }
}

/**
 * A rule-bordered strip: on today a live clock and a countdown to midnight, otherwise a blurb
 * about the day; always the count of outstanding flagged ("priority") items.
 */
@Composable
fun BriefingRow(state: CockpitUiState, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth()) {
        PaperRule()
        Row(
            Modifier.fillMaxWidth().padding(vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (state.context.isToday) {
                val time by rememberTickingTime()
                BriefingItem(Icons.Outlined.Schedule, time.toLocalTime().formatShort())
                PaperVerticalRule()
                BriefingItem(Icons.Outlined.HourglassBottom, Briefing.remainingLabel(time))
            } else {
                BriefingItem(null, Briefing.dayBlurb(state.date, state.now.toLocalDate()))
            }
            PaperVerticalRule()
            BriefingItem(Icons.Outlined.AutoAwesome, Briefing.priorityLabel(state.priorityCount))
        }
        PaperRule()
    }
}

@Composable
private fun BriefingItem(icon: ImageVector?, text: String) {
    val colors = CockpitStyle.colors
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = colors.ink, modifier = Modifier.size(12.dp))
        }
        Text(
            text = text,
            style = CockpitStyle.mono(CockpitTextStyle.Caption2),
            color = colors.muted,
            maxLines = 1,
            overflow = TextOverflow.Clip,
        )
    }
}
