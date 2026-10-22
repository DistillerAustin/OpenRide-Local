package dev.digitalducktape.openride.ui.creator

import dev.digitalducktape.openride.core.content.PlaylistSummary
import dev.digitalducktape.openride.core.content.Video
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaylistShelfTest {

    private val playlist = PlaylistSummary("p1", "Climbs", "", 3)
    private val video = Video("v1", "Climb", "", "Hill Club", null, 1)

    @Test
    fun `a fresh shelf asks for its playlist`() {
        val row = PlaylistRow(playlist)
        assertTrue(PlaylistShelf.needsLoad(row))
        assertEquals(PlaylistShelf.Videos, PlaylistShelf.of(row))
    }

    @Test
    fun `a loading shelf shows the spinner and doesn't ask again`() {
        val row = PlaylistRow(playlist, isLoading = true)
        assertEquals(PlaylistShelf.Loading, PlaylistShelf.of(row))
        assertFalse(PlaylistShelf.needsLoad(row))
    }

    @Test
    fun `a failed shelf says so and doesn't retry on its own`() {
        val row = PlaylistRow(playlist, loadFailed = true)
        assertEquals(PlaylistShelf.Failed, PlaylistShelf.of(row))
        assertFalse(PlaylistShelf.needsLoad(row))
    }

    @Test
    fun `a loaded shelf shows its classes`() {
        val row = PlaylistRow(playlist, videos = listOf(video))
        assertEquals(PlaylistShelf.Videos, PlaylistShelf.of(row))
        assertFalse(PlaylistShelf.needsLoad(row))
    }
}
