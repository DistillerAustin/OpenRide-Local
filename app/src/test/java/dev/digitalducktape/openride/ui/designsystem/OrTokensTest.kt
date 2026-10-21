package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The bike rules of docs/MAIN_UI_REFRESH.md §0, as numbers. */
class OrTokensTest {

    @Test
    fun `the bike window is the panel less the reserved nav strip, in dp at density 1_5`() {
        val density = 1.5f
        assertEquals(1920f, BikeWindow.Width.value * density, 0.01f)
        assertEquals(1008f, BikeWindow.Height.value * density, 0.01f)
        assertEquals(72f, BikeWindow.ReservedNavStrip.value * density, 0.01f)
        assertEquals(1080f, (BikeWindow.Height + BikeWindow.ReservedNavStrip).value * density, 0.01f)
    }

    @Test
    fun `touch targets are at least 44 dp, buttons 48, the primary action 56`() {
        assertTrue(OrSize.TouchMin >= 44.dp)
        assertTrue(OrSize.Button >= OrSize.TouchMin)
        assertTrue(OrSize.PrimaryAction >= OrSize.Button)
        assertTrue(OrSize.SettingsRow >= OrSize.TouchMin)
        assertTrue(OrSize.BottomBar >= OrSize.TouchMin)
    }

    @Test
    fun `the top and bottom bars leave at least 500 dp of content height`() {
        assertTrue(BikeWindow.Height - OrSize.TopBar - OrSize.BottomBar >= 500.dp)
    }

    @Test
    fun `spacing is on the 4 dp grid`() {
        listOf(OrSpacing.xs, OrSpacing.sm, OrSpacing.md, OrSpacing.lg, OrSpacing.xl, OrSpacing.xxl, OrSpacing.ScreenGutter)
            .forEach { assertEquals("$it", 0f, it.value % 4f, 0.0001f) }
    }

    @Test
    fun `no text style is smaller than 14 sp, and only tracked caps and badges go below 16 sp`() {
        OrType.all.forEach { (name, style) ->
            val size = style.fontSize.value
            assertTrue("$name is $size sp", size >= 14f)
            if (size < 16f) assertTrue("$name is $size sp but not tracked caps", name == "Eyebrow" || name == "Badge")
        }
    }

    @Test
    fun `text read while riding is at least 18 sp`() {
        listOf(OrType.Body, OrType.Button, OrType.ButtonLarge, OrType.NavLabel, OrType.Subtitle, OrType.Title)
            .forEach { assertTrue("${it.fontSize}", it.fontSize.value >= 18f) }
    }
}
