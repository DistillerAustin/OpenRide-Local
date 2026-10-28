package dev.digitalducktape.openride.core.music

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationManagerCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** What the rider's music app is playing (or has paused), as its media session reports it. */
data class NowPlaying(
    val packageName: String,
    val title: String,
    val artist: String,
    val art: Bitmap?,
    /** A content:// or https:// image, when the app gives a link instead of a bitmap. */
    val artUri: String?,
    val isPlaying: Boolean,
    val canPrevious: Boolean,
    val canNext: Boolean,
)

/**
 * Mirrors whichever music app is playing, by watching Android's media sessions: the same data
 * the system's own media controls draw from, so every app that has them works (Apple Music,
 * Spotify, Pandora, SiriusXM, ...) with no per-service integration.
 *
 * Android hands other apps' sessions only to an app the rider has given Notification access
 * ([NowPlayingListenerService]); until then [hasAccess] is false and [nowPlaying] stays null.
 * Call [refresh] when a screen comes back to the front, since the grant happens in Settings.
 *
 * Apps drop their session a while after being paused (SiriusXM within minutes, Spotify sooner),
 * and [nowPlaying] goes back to null; the player then offers the rider's [defaultApp] instead.
 */
class NowPlayingMonitor(context: Context) {
    private val app = context.applicationContext
    private val manager = app.getSystemService(MediaSessionManager::class.java)
    private val listener = ComponentName(app, NowPlayingListenerService::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private val access = MutableStateFlow(false)
    val hasAccess: StateFlow<Boolean> = access.asStateFlow()

    private val state = MutableStateFlow<NowPlaying?>(null)
    val nowPlaying: StateFlow<NowPlaying?> = state.asStateFlow()

    private val chosenApp = MutableStateFlow(prefs.getString(KEY_DEFAULT_APP, null))

    /** The package of the music app the rider chose in Profile (or from the player), if any. */
    val defaultApp: StateFlow<String?> = chosenApp.asStateFlow()

    fun setDefaultApp(packageName: String) {
        prefs.edit().putString(KEY_DEFAULT_APP, packageName).apply()
        chosenApp.value = packageName
    }

    /** The component the rider grants Notification access to. */
    val listenerComponent: ComponentName
        get() = listener

    private var controllers: List<MediaController> = emptyList()
    private var current: MediaController? = null
    private var registered = false

    private val controllerCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) = publish()
        override fun onMetadataChanged(metadata: MediaMetadata?) = publish()
        override fun onSessionDestroyed() = publish()
    }

    private val sessionsListener = MediaSessionManager.OnActiveSessionsChangedListener { list ->
        setControllers(list.orEmpty())
    }

    /** Re-checks the grant and re-reads the sessions. Cheap; safe to call on every resume. */
    fun refresh() {
        val granted = NotificationManagerCompat.getEnabledListenerPackages(app).contains(app.packageName)
        access.value = granted
        if (!granted) {
            teardown()
            return
        }
        try {
            if (!registered) {
                manager.addOnActiveSessionsChangedListener(sessionsListener, listener, handler)
                registered = true
            }
            setControllers(manager.getActiveSessions(listener))
        } catch (e: SecurityException) {
            Log.w(TAG, "media sessions refused despite the grant", e)
            access.value = false
            teardown()
        }
    }

    // Media-button events, the way a headset button does it: SiriusXM ignores another app's
    // direct transport commands but obeys these, and Spotify doesn't offer a plain "play".
    fun playPause() = sendKey(if (state.value?.isPlaying == true) KeyEvent.KEYCODE_MEDIA_PAUSE else KeyEvent.KEYCODE_MEDIA_PLAY)

    fun next() = sendKey(KeyEvent.KEYCODE_MEDIA_NEXT)

    fun previous() = sendKey(KeyEvent.KEYCODE_MEDIA_PREVIOUS)

    private fun sendKey(code: Int) {
        val c = current ?: return
        c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        c.dispatchMediaButtonEvent(KeyEvent(KeyEvent.ACTION_UP, code))
    }

    /** Brings the playing app forward: its own player screen when it offers one, else its launcher entry. */
    fun openApp() {
        val c = current ?: return
        val sessionActivity = c.sessionActivity
        val opened = sessionActivity != null && runCatching { sessionActivity.send() }.isSuccess
        if (!opened) MusicApps.open(app, c.packageName)
    }

    private fun setControllers(list: List<MediaController>) {
        controllers.forEach { it.unregisterCallback(controllerCallback) }
        controllers = list.filter { it.packageName != app.packageName }
        controllers.forEach { it.registerCallback(controllerCallback, handler) }
        publish()
    }

    private fun teardown() {
        controllers.forEach { it.unregisterCallback(controllerCallback) }
        controllers = emptyList()
        current = null
        if (registered) {
            manager.removeOnActiveSessionsChangedListener(sessionsListener)
            registered = false
        }
        state.value = null
    }

    private fun publish() {
        val pick = NowPlayingRules.pick(
            controllers,
            isPlaying = { it.playbackState?.isPlaying() == true },
            hasTitle = { it.metadata?.title() != null },
        )
        current = pick
        state.value = pick?.let(::toNowPlaying)
    }

    private fun toNowPlaying(c: MediaController): NowPlaying? {
        val meta = c.metadata ?: return null
        val title = meta.title() ?: return null
        val playback = c.playbackState
        val actions = playback?.actions ?: 0L
        return NowPlaying(
            packageName = c.packageName,
            title = title,
            artist = NowPlayingRules.firstPresent(
                meta.getString(MediaMetadata.METADATA_KEY_ARTIST),
                meta.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST),
                meta.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE),
            ).orEmpty(),
            art = meta.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: meta.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: meta.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON),
            artUri = NowPlayingRules.firstPresent(
                meta.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI),
                meta.getString(MediaMetadata.METADATA_KEY_ART_URI),
                meta.getString(MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI),
            ),
            isPlaying = playback?.isPlaying() == true,
            canPrevious = actions and PlaybackState.ACTION_SKIP_TO_PREVIOUS != 0L,
            canNext = actions and PlaybackState.ACTION_SKIP_TO_NEXT != 0L,
        )
    }

    private fun MediaMetadata.title(): String? = NowPlayingRules.firstPresent(
        getString(MediaMetadata.METADATA_KEY_TITLE),
        getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE),
    )

    private fun PlaybackState.isPlaying() =
        state == PlaybackState.STATE_PLAYING || state == PlaybackState.STATE_BUFFERING

    private companion object {
        const val TAG = "NowPlaying"
        const val PREFS = "music"
        const val KEY_DEFAULT_APP = "default_app"
    }
}

/** [NowPlayingMonitor]'s choices, kept free of Android types so they can be unit-tested. */
object NowPlayingRules {
    /**
     * The session to show: the one playing, else the first with a title. Android lists sessions
     * most recently active first, so a paused app stays up until another one plays.
     */
    fun <T> pick(sessions: List<T>, isPlaying: (T) -> Boolean, hasTitle: (T) -> Boolean): T? =
        sessions.firstOrNull { isPlaying(it) && hasTitle(it) } ?: sessions.firstOrNull(hasTitle)

    /** The first value that has text in it. */
    fun firstPresent(vararg values: String?): String? = values.firstOrNull { !it.isNullOrBlank() }
}
