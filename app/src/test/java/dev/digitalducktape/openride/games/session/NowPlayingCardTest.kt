package dev.digitalducktape.openride.games.session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NowPlayingCardTest {
    @Test
    fun `the card's wire words map to the player's actions, and nothing else does`() {
        assertEquals(NowPlayingCard.Action.PLAY_PAUSE, NowPlayingCard.action("play_pause"))
        assertEquals(NowPlayingCard.Action.NEXT, NowPlayingCard.action("next"))
        assertEquals(NowPlayingCard.Action.PREVIOUS, NowPlayingCard.action("previous"))
        assertNull(NowPlayingCard.action("stop"))
    }

    @Test
    fun `each track's art gets its own file name, the same every time`() {
        val key = NowPlayingCard.artKey("com.spotify.music", "Song", "Band")
        assertEquals(key, NowPlayingCard.artKey("com.spotify.music", "Song", "Band"))
        assertNotEquals(key, NowPlayingCard.artKey("com.spotify.music", "Other song", "Band"))
        assertEquals(Regex("[0-9a-f]{8}").matches(key), true)
    }
}
