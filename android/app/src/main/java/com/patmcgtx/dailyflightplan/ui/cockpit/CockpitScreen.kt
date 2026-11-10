package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/**
 * Cockpit tab. Scaffold-phase placeholder: shows just the date header so the theme and bundled
 * font can be checked on device. The real screen is built bottom-up in plan phase 4.
 */
@Composable
fun CockpitScreen(modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    val today = LocalDate.now()
    val shortDate = "${today.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())} ${today.dayOfMonth}"
    val weekday = today.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = shortDate.uppercase(),
            style = CockpitStyle.mono(CockpitTextStyle.Subheadline),
            color = colors.muted,
        )
        Text(
            text = weekday.uppercase(),
            style = CockpitStyle.mono(CockpitTextStyle.LargeTitle, FontWeight.Bold),
            color = colors.ink,
        )
    }
}
