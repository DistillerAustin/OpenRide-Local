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
        assertNotEquals(Color(0xFFE8442D), OrColors.DefaultAccent)
        // Green dominates the accent: a hue far from red.
        assertTrue(OrColors.DefaultAccent.green > OrColors.DefaultAccent.red)
    }

    @Test
    fun `the background is not pure black`() {
        assertNotEquals(Color.Black, OrColors.Background)
    }

    @Test
    fun `no avatar colour gives an accent that reads as a status colour`() {
        dev.digitalducktape.openride.ui.profile.AvatarOptions.colors.forEach { avatar ->
            val (h, s, _) = hsv(riderAccent(avatar))
            if (s < 0.2f) return@forEach
            StatusHues.forEach { status ->
                assertTrue(
                    "avatar ${Integer.toHexString(avatar)}: hue $h within $ACCENT_HUE_CLEARANCE of $status",
                    hueDistance(h, status) >= ACCENT_HUE_CLEARANCE - 0.5f,
                )
            }
        }
    }

    @Test
    fun `a status-coloured avatar turns to the nearest clear hue`() {
        // Danger's own red would read as Danger: it moves, but no further than the clearance.
        val (dangerHue) = hsv(OrColors.Danger)
        val (h) = hsv(clearOfStatusHues(OrColors.Danger))
        assertTrue(hueDistance(h, dangerHue) >= ACCENT_HUE_CLEARANCE - 0.5f)
        StatusHues.forEach { assertTrue(hueDistance(h, it) >= ACCENT_HUE_CLEARANCE - 0.5f) }
    }

    @Test
    fun `colours clear of the status hues, and greys, are left alone`() {
        val blue = Color(0xFF2D9CE8)
        assertTrue(clearOfStatusHues(blue) == blue)
        val grey = Color(0xFFB0BEC5)
        assertTrue(clearOfStatusHues(grey) == grey)
    }
}
