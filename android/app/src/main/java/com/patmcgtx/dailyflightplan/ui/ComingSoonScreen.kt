package com.patmcgtx.dailyflightplan.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle

/** Placeholder body for tabs that aren't built yet. */
@Composable
fun ComingSoonScreen(title: String, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    Column(
        modifier = modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = title.uppercase(),
            style = CockpitStyle.mono(CockpitTextStyle.Title2, FontWeight.Bold),
            color = colors.ink,
            textAlign = TextAlign.Center,
        )
        Text(
            text = "COMING SOON",
            style = CockpitStyle.mono(CockpitTextStyle.Caption),
            color = colors.muted,
            textAlign = TextAlign.Center,
        )
    }
}
