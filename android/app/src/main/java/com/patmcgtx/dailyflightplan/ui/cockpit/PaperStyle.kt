package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle

/**
 * The Cockpit's "filed paper" box: a flat fill, a square black border, and a hard (unblurred)
 * offset shadow — no rounded corners, no elevation. Shadow offset defaults match the section cards.
 */
@Composable
fun Modifier.paperCard(
    borderWidth: Dp = 1.5.dp,
    shadowOffset: DpOffset = DpOffset(3.dp, 4.dp),
    fill: Color = CockpitStyle.colors.surface,
): Modifier {
    val colors = CockpitStyle.colors
    return this
        .drawBehind {
            drawRect(
                color = colors.shadow,
                topLeft = Offset(shadowOffset.x.toPx(), shadowOffset.y.toPx()),
                size = size,
            )
            drawRect(color = fill, size = size)
        }
        .border(borderWidth, colors.border)
}

/** A thin horizontal rule in the border color, as between rows inside a card. */
@Composable
fun PaperRule(modifier: Modifier = Modifier, alpha: Float = 0.4f) {
    Box(
        modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(CockpitStyle.colors.border.copy(alpha = alpha)),
    )
}

/** A thin vertical rule, as between the items of the briefing strip. */
@Composable
fun PaperVerticalRule(modifier: Modifier = Modifier, height: Dp = 14.dp) {
    Box(
        modifier
            .width(1.dp)
            .height(height)
            .background(CockpitStyle.colors.border.copy(alpha = 0.4f)),
    )
}
