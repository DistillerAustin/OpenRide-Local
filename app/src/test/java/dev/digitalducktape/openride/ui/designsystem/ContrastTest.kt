package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContrastTest {

    @Test
    fun `black on white is the maximum 21 to 1`() {
        assertEquals(21.0, contrastRatio(Color.Black, Color.White), 0.01)
    }

    @Test
    fun `a colour on itself is 1 to 1`() {
        assertEquals(1.0, contrastRatio(OrColors.DefaultAccent, OrColors.DefaultAccent), 0.0001)
    }

    @Test
    fun `contrast is symmetric`() {
        assertEquals(
            contrastRatio(OrColors.OnBackground, OrColors.Surface),
            contrastRatio(OrColors.Surface, OrColors.OnBackground),
            0.0001,
        )
    }

    @Test
    fun `luminance matches the WCAG reference values`() {
        assertEquals(0.0, relativeLuminance(Color.Black), 0.0001)
        assertEquals(1.0, relativeLuminance(Color.White), 0.0001)
        // Mid grey #777777 is the textbook 4.48 : 1 on white.
        assertEquals(4.48, contrastRatio(Color(0xFF777777), Color.White), 0.01)
    }

    @Test
    fun `a translucent foreground is composited before measuring`() {
        val halfWhite = Color.White.copy(alpha = 0.5f)
        val ratio = contrastRatio(halfWhite, Color.Black)
        assertTrue("got $ratio", ratio > 1.0 && ratio < 21.0)
    }
}
