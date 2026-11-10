package com.patmcgtx.dailyflightplan.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

/**
 * Applies the Cockpit palette app-wide. Material's color scheme is derived from the Cockpit
 * tokens so stock components (navigation bar, sheets) pick up the paper look automatically.
 */
@Composable
fun CockpitTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkCockpitColors else LightCockpitColors
    val scheme = if (darkTheme) {
        darkColorScheme(
            primary = colors.ink,
            onPrimary = colors.background,
            background = colors.background,
            onBackground = colors.ink,
            surface = colors.surface,
            onSurface = colors.ink,
            onSurfaceVariant = colors.muted,
            outline = colors.border,
        )
    } else {
        lightColorScheme(
            primary = colors.ink,
            onPrimary = colors.background,
            background = colors.background,
            onBackground = colors.ink,
            surface = colors.surface,
            onSurface = colors.ink,
            onSurfaceVariant = colors.muted,
            outline = colors.border,
        )
    }

    CompositionLocalProvider(LocalCockpitColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
