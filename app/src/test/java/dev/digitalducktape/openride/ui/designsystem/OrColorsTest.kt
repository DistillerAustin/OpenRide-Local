package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OrColorsTest {

    @Test
    fun `every colour pair the design system draws meets its contrast floor`() {
        val failures = OrColorPairs.mapNotNull { pair ->
            val ratio = contrastRatio(pair.foreground, pair.background)
            if (ratio < pair.minContrast) "${pair.name}: %.2f < %.1f".format(ratio, pair.minContrast) else null
        }
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }

    @Test
    fun `body text pairs use the WCAG AA floor`() {
        val textPairs = OrColorPairs.filter { it.name.contains("text") }
        assertTrue(textPairs.isNotEmpty())
        textPairs.forEach { assertTrue(it.name, it.minContrast >= 4.5) }
    }

    @Test
    fun `the accent is not the previous red, so the app no longer reads as red on black`() {
        assertNotEquals(Color(0xFFE8442D), OrColors.Accent)
        // Green dominates the accent: a hue far from red.
        assertTrue(OrColors.Accent.green > OrColors.Accent.red)
    }

    @Test
    fun `the background is not pure black`() {
        assertNotEquals(Color.Black, OrColors.Background)
    }
}
