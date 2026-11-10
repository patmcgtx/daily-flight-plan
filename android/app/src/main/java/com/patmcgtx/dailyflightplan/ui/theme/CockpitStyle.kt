package com.patmcgtx.dailyflightplan.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.patmcgtx.dailyflightplan.R

/**
 * Color tokens for the Cockpit look — a filed-flight-plan, typewritten feel (monospaced type, flat
 * borders, highlighter-yellow accents). Ported from the iOS `Theming/CockpitStyle.swift`; the
 * values must stay in sync with it. Dark mode is "Paper Night".
 */
@Immutable
data class CockpitColors(
    val background: Color,
    val surface: Color,
    val ink: Color,
    val muted: Color,
    val border: Color,
    val highlighter: Color,
    val routeBlue: Color,
    val shadow: Color,
    /** Status text/ring colors. Each theme's value meets 4.5:1 against its surface (see `ContrastTest`). */
    val done: Color,
    val overdue: Color,
    val now: Color,
)

val LightCockpitColors = CockpitColors(
    background = Color(0xFFE9E5DA),
    surface = Color(0xFFF8F7F1),
    ink = Color(0xFF101010),
    muted = Color(0xFF555555),
    border = Color(0xFF111111),
    highlighter = Color(0xFFF2ED37),
    routeBlue = Color(0xFF51699A),
    shadow = Color.Black.copy(alpha = 0.18f),
    done = Color(0xFF1B7A3B),
    overdue = Color(0xFFA85600),
    now = Color(0xFFC62828),
)

val DarkCockpitColors = CockpitColors(
    background = Color(0xFF0A0D12),
    surface = Color(0xFF12171D),
    ink = Color(0xFFF3F5F7),
    muted = Color(0xFF9AA6B2),
    border = Color(0xFF6F7A85),
    highlighter = Color(0xFFF1C84C),
    routeBlue = Color(0xFF7FA9DC),
    shadow = Color.Black.copy(alpha = 0.18f),
    done = Color(0xFF4CC46E),
    overdue = Color(0xFFF5A524),
    now = Color(0xFFFF6B6B),
)

val LocalCockpitColors = staticCompositionLocalOf { LightCockpitColors }

/** Type scale names, mirroring the SwiftUI `Font.TextStyle` sizes at the default content size. */
enum class CockpitTextStyle(val size: Float) {
    LargeTitle(34f),
    Title(28f),
    Title2(22f),
    Title3(20f),
    Headline(17f),
    Body(17f),
    Callout(16f),
    Subheadline(15f),
    Footnote(13f),
    Caption(12f),
    Caption2(11f),
}

object CockpitStyle {

    val colors: CockpitColors
        @androidx.compose.runtime.Composable
        @ReadOnlyComposable
        get() = LocalCockpitColors.current

    /** Text sitting on the highlighter yellow always needs dark ink, in both color schemes. */
    val inkOnHighlighter = Color(0xFF101010)

    /** IBM Plex Mono, bundled in `res/font` in the three weights the iOS app ships. */
    val monoFamily = FontFamily(
        Font(R.font.ibm_plex_mono_regular, FontWeight.Normal),
        Font(R.font.ibm_plex_mono_semibold, FontWeight.SemiBold),
        Font(R.font.ibm_plex_mono_bold, FontWeight.Bold),
    )

    /** Equivalent of the iOS `CockpitStyle.mono(_:weight:)`. */
    fun mono(style: CockpitTextStyle, weight: FontWeight = FontWeight.Normal): TextStyle =
        TextStyle(fontFamily = monoFamily, fontSize = style.size.sp, fontWeight = weight)
}
