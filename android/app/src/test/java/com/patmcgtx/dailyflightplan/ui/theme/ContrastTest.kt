package com.patmcgtx.dailyflightplan.ui.theme

import androidx.compose.ui.graphics.Color
import java.util.stream.Stream
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.Arguments
import org.junit.jupiter.params.provider.Arguments.arguments
import org.junit.jupiter.params.provider.MethodSource

/**
 * WCAG 2.x contrast checks on the Cockpit palette, so a color tweak can't quietly make text
 * unreadable. Parameters are color *names* (Compose's `Color` is a value class JUnit can't pass).
 */
class ContrastTest {

    private fun channel(c: Float): Double {
        val v = c.toDouble()
        return if (v <= 0.03928) v / 12.92 else Math.pow((v + 0.055) / 1.055, 2.4)
    }

    private fun luminance(color: Color): Double =
        0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)

    private fun ratio(a: Color, b: Color): Double {
        val (hi, lo) = listOf(luminance(a), luminance(b)).sortedDescending()
        return (hi + 0.05) / (lo + 0.05)
    }

    private fun color(theme: String, name: String): Color {
        val c = if (theme == "light") LightCockpitColors else DarkCockpitColors
        return when (name) {
            "ink" -> c.ink
            "muted" -> c.muted
            "done" -> c.done
            "overdue" -> c.overdue
            "now" -> c.now
            "border" -> c.border
            "routeBlue" -> c.routeBlue
            "surface" -> c.surface
            "background" -> c.background
            "highlighter" -> c.highlighter
            "inkOnHighlighter" -> CockpitStyle.inkOnHighlighter
            else -> error("unknown color $name")
        }
    }

    private fun assertRatio(theme: String, fg: String, bg: String, minimum: Double) {
        val actual = ratio(color(theme, fg), color(theme, bg))
        assertTrue(actual >= minimum, "$theme: $fg on $bg is ${"%.2f".format(actual)}:1, needs $minimum:1")
    }

    @ParameterizedTest(name = "{0}: {1} on {2} is at least 4.5:1")
    @MethodSource("textPairs")
    fun `Text colors have at least 4_5 to 1 contrast against the paper they sit on`(theme: String, fg: String, bg: String) {
        assertRatio(theme, fg, bg, 4.5)
    }

    @ParameterizedTest(name = "{0}: {1} on {2} is at least 3:1")
    @MethodSource("graphicPairs")
    fun `Borders and icons have at least 3 to 1 contrast against the paper`(theme: String, fg: String, bg: String) {
        assertRatio(theme, fg, bg, 3.0)
    }

    companion object {
        private val themes = listOf("light", "dark")

        @JvmStatic
        fun textPairs(): Stream<Arguments> = themes.flatMap { theme ->
            // Ink and muted also sit directly on the page; status colors only appear inside cards.
            val onPage = listOf("ink", "muted").map { arguments(theme, it, "background") }
            val onCard = listOf("ink", "muted", "done", "overdue", "now").map { arguments(theme, it, "surface") }
            onPage + onCard + arguments(theme, "inkOnHighlighter", "highlighter")
        }.stream()

        @JvmStatic
        fun graphicPairs(): Stream<Arguments> = themes.flatMap { theme ->
            listOf(
                arguments(theme, "border", "background"),
                arguments(theme, "border", "surface"),
                arguments(theme, "routeBlue", "surface"),
            )
        }.stream()
    }
}
