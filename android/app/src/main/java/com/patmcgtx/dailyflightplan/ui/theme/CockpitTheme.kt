package com.patmcgtx.dailyflightplan.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

/**
 * Applies the Cockpit palette app-wide. Material's color scheme is derived from the Cockpit
 * tokens so stock components (navigation bar, menus, sheets, date and time pickers) pick up the
 * paper look instead of Material's default purple tonal palette.
 */
@Composable
fun CockpitTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkCockpitColors else LightCockpitColors
    val scheme = cockpitColorScheme(colors, darkTheme)

    CompositionLocalProvider(LocalCockpitColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

private fun cockpitColorScheme(colors: CockpitColors, dark: Boolean): ColorScheme {
    val onHighlighter = CockpitStyle.inkOnHighlighter
    val base = if (dark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = colors.ink,
        onPrimary = colors.background,
        primaryContainer = colors.highlighter,
        onPrimaryContainer = onHighlighter,
        secondary = colors.ink,
        onSecondary = colors.background,
        secondaryContainer = colors.highlighter,
        onSecondaryContainer = onHighlighter,
        tertiary = colors.routeBlue,
        onTertiary = colors.background,
        tertiaryContainer = colors.highlighter,
        onTertiaryContainer = onHighlighter,
        background = colors.background,
        onBackground = colors.ink,
        surface = colors.surface,
        onSurface = colors.ink,
        surfaceVariant = colors.background,
        onSurfaceVariant = colors.muted,
        surfaceTint = colors.surface,
        surfaceContainerLowest = colors.surface,
        surfaceContainerLow = colors.surface,
        surfaceContainer = colors.surface,
        surfaceContainerHigh = colors.surface,
        surfaceContainerHighest = colors.background,
        outline = colors.border,
        outlineVariant = colors.border.copy(alpha = 0.4f),
        scrim = androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.5f),
    )
}
