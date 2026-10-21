package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.graphics.Color
import dev.digitalducktape.openride.ui.profile.AvatarOptions
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The rider's UI colour comes from their avatar colour, and is always readable. */
class RiderAccentTest {

    @Test
    fun `every avatar colour gives a readable accent`() {
        AvatarOptions.colors.forEach { avatar ->
            val accent = riderAccent(avatar)
            assertTrue("avatar ${Integer.toHexString(avatar)} -> $accent", accentReadable(accent))
        }
    }

    @Test
    fun `every avatar colour keeps its own hue rather than falling back to the default`() {
        AvatarOptions.colors.forEach { avatar ->
            assertNotEquals("avatar ${Integer.toHexString(avatar)}", OrColors.DefaultAccent, riderAccent(avatar))
        }
    }

    @Test
    fun `a colour that is already readable is used as it is`() {
        val light = 0xFF4DD0C4.toInt()
        assertEquals(Color(light), riderAccent(light))
    }

    @Test
    fun `no rider gives the default accent`() {
        assertEquals(OrColors.DefaultAccent, riderAccent(null))
    }
}
