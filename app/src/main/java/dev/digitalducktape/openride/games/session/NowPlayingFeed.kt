package dev.digitalducktape.openride.games.session

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import dev.digitalducktape.openride.core.music.NowPlaying
import dev.digitalducktape.openride.core.music.NowPlayingMonitor
import dev.digitalducktape.openride.games.bridge.BridgeMessages
import dev.digitalducktape.openride.games.bridge.NowPlayingMessage
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach

/**
 * The Games hub's music card (docs/GAMES.md, "Music card"): sends the rider's music app's track
 * to Godot as `now_playing`, with its album art saved as a PNG the hub can load, and carries the
 * card's buttons back to the app's [NowPlayingMonitor].
 */
class NowPlayingFeed(
    private val context: Context,
    monitor: NowPlayingMonitor,
    private val publish: (String) -> Unit,
    scope: CoroutineScope,
) {
    private val artDir = File(context.cacheDir, "games/now_playing")

    init {
        monitor.nowPlaying
            .map { it?.let(::message) }
            .distinctUntilChanged()
            .onEach { publish(BridgeMessages.encode(it)) }
            .flowOn(Dispatchers.IO)
            .launchIn(scope)
    }

    private fun message(playing: NowPlaying) = NowPlayingMessage(
        title = playing.title,
        artist = playing.artist,
        art = art(playing),
        playing = playing.isPlaying,
        canPrevious = playing.canPrevious,
        canNext = playing.canNext,
    )

    /**
     * The track's art as a PNG, written once per track (a new name for each, since the hub caches
     * images by path), or "" when the app gives none it can read (a web link, say).
     */
    private fun art(playing: NowPlaying): String {
        val file = File(artDir, "${NowPlayingCard.artKey(playing.packageName, playing.title, playing.artist)}.png")
        if (file.exists()) return file.absolutePath
        val bitmap = playing.art ?: playing.artUri?.let(::loadUri) ?: return ""
        return runCatching {
            artDir.mkdirs()
            artDir.listFiles()?.forEach { it.delete() }
            val scaled = Bitmap.createScaledBitmap(bitmap, ART_PX, ART_PX, true)
            file.outputStream().use { scaled.compress(Bitmap.CompressFormat.PNG, 100, it) }
            file.absolutePath
        }.getOrElse {
            Log.w(TAG, "couldn't save the album art", it)
            ""
        }
    }

    /** A `content://` art link (Pandora's); others aren't fetched here. */
    private fun loadUri(uri: String): Bitmap? = runCatching {
        if (!uri.startsWith("content://")) return null
        context.contentResolver.openInputStream(Uri.parse(uri))?.use(BitmapFactory::decodeStream)
    }.getOrNull()

    companion object {
        private const val TAG = "NowPlayingFeed"

        /** The card shows it at 104 px; twice that stays sharp. */
        private const val ART_PX = 208

        private val main = Handler(Looper.getMainLooper())

        /** The hub card's buttons, on the main thread where the monitor's controller lives. */
        fun control(monitor: NowPlayingMonitor, action: String) {
            Log.w(TAG, "music_control $action for ${monitor.nowPlaying.value?.packageName ?: "no app"}")
            main.post {
                when (NowPlayingCard.action(action)) {
                    NowPlayingCard.Action.PLAY_PAUSE -> monitor.playPause()
                    NowPlayingCard.Action.NEXT -> monitor.next()
                    NowPlayingCard.Action.PREVIOUS -> monitor.previous()
                    null -> Log.w(TAG, "music_control: ignoring '$action'")
                }
            }
        }
    }
}

/** The music card's rules, kept free of Android types so they can be unit-tested. */
object NowPlayingCard {
    enum class Action { PLAY_PAUSE, NEXT, PREVIOUS }

    /** `music_control`'s wire words. */
    fun action(word: String): Action? = when (word) {
        "play_pause" -> Action.PLAY_PAUSE
        "next" -> Action.NEXT
        "previous" -> Action.PREVIOUS
        else -> null
    }

    /** A file-name-safe key for one track's art. */
    fun artKey(packageName: String, title: String, artist: String): String =
        "%08x".format("$packageName|$title|$artist".hashCode())
}
