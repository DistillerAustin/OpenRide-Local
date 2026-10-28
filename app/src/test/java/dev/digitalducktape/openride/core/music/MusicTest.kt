package dev.digitalducktape.openride.core.music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MusicTest {

    private data class Session(val name: String, val playing: Boolean, val titled: Boolean = true)

    private fun pick(vararg sessions: Session) =
        NowPlayingRules.pick(sessions.toList(), isPlaying = { it.playing }, hasTitle = { it.titled })?.name

    @Test
    fun `the player shows the app that is playing, wherever Android lists it`() {
        assertEquals("spotify", pick(Session("pandora", playing = false), Session("spotify", playing = true)))
    }

    @Test
    fun `with nothing playing, the most recent app with a song stays up`() {
        assertEquals("apple", pick(Session("sirius", playing = false, titled = false), Session("apple", playing = false)))
    }

    @Test
    fun `an app playing with no song yet doesn't win over one with a song`() {
        assertEquals("apple", pick(Session("sirius", playing = true, titled = false), Session("apple", playing = false)))
    }

    @Test
    fun `no song anywhere, no player`() {
        assertNull(pick(Session("pandora", playing = true, titled = false)))
        assertNull(pick())
    }

    @Test
    fun `the first value with text in it wins`() {
        assertEquals("Bruno Mars", NowPlayingRules.firstPresent(null, " ", "Bruno Mars", "Unorthodox Jukebox"))
        assertNull(NowPlayingRules.firstPresent(null, ""))
    }

    @Test
    fun `music apps are listed by name, whatever their case`() {
        val apps = listOf(
            MusicApp("com.sirius", "SiriusXM"),
            MusicApp("com.spotify.music", "Spotify"),
            MusicApp("com.apple.android.music", "Apple Music"),
            MusicApp("com.pandora.android", "pandora"),
        )
        assertEquals(
            listOf("Apple Music", "pandora", "SiriusXM", "Spotify"),
            MusicApps.order(apps, exclude = "dev.digitalducktape.openride").map { it.label },
        )
    }

    @Test
    fun `OpenRide, nameless apps and duplicates are left out`() {
        val apps = listOf(
            MusicApp("dev.digitalducktape.openride", "OpenRide"),
            MusicApp("com.onepeloton.launcher", " "),
            MusicApp("com.spotify.music", "Spotify"),
            MusicApp("com.spotify.music", "Spotify"),
        )
        assertEquals(
            listOf("Spotify"),
            MusicApps.order(apps, exclude = "dev.digitalducktape.openride").map { it.label },
        )
    }
}
