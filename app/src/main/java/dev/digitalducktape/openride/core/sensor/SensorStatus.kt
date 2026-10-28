package dev.digitalducktape.openride.core.sensor

import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.transformLatest
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** How long the sensors must stay away before the app says so (issue #56): a blip never shows. */
val SensorOfflineAfter: Duration = 10.seconds

/**
 * `true` once this connection has been anything but [ConnectionState.Connected] for [after]
 * without a break, and `false` again the moment it reconnects. The one rule for "sensors
 * offline" everywhere (issue #56): the top bar's dot and notice, the ride screens' banner and
 * blank tiles, and the games' `sensors_ok`, all through `AppContainer.sensorsOffline`. Emits
 * nothing until it knows: an offline start stays silent for [after].
 */
@OptIn(ExperimentalCoroutinesApi::class)
fun Flow<ConnectionState>.offlineFor(after: Duration = SensorOfflineAfter): Flow<Boolean> =
    map { it != ConnectionState.Connected }
        .distinctUntilChanged()
        .transformLatest { offline ->
            if (offline) {
                delay(after)
                emit(true)
            } else {
                emit(false)
            }
        }
        // A blip re-emits `false`; nobody needs to hear it twice.
        .distinctUntilChanged()

/** How long a bound source may go without a frame before it counts as dropped (issue #56). */
const val SENSOR_SILENT_AFTER_MS = 3_000L

/** How often [watchFrames] looks at the frame count. */
private const val FRAME_CHECK_MS = 250L

/**
 * Keeps [into] equal to [upstream], except that a source which says
 * [ConnectionState.Connected] but has delivered no frame for [silentAfterMs] reads
 * [ConnectionState.Disconnected] until frames flow again (issue #56).
 *
 * That is the board going quiet behind a live binding: Peloton's sensor service stays bound
 * and the callback stays registered, but the board stops answering ("cannot perform
 * getBikeData when platform is not detected"), so no frame arrives and nothing else changes.
 * The service pushes about 21 frames a second even when nobody pedals (docs/DEVICE.md), and
 * the poll fallback reads one a second, so [silentAfterMs] of nothing is never a quiet rider.
 *
 * @param frames the source's running count of decoded frames.
 */
fun CoroutineScope.watchFrames(
    upstream: StateFlow<ConnectionState>,
    frames: () -> Long,
    into: MutableStateFlow<ConnectionState>,
    silentAfterMs: Long = SENSOR_SILENT_AFTER_MS,
): Job = launch {
    var last = frames()
    var quietMs = 0L
    while (isActive) {
        val now = frames()
        quietMs = if (now != last) 0L else quietMs + FRAME_CHECK_MS
        last = now
        val state = upstream.value
        into.value = if (state == ConnectionState.Connected && quietMs >= silentAfterMs) ConnectionState.Disconnected else state
        delay(FRAME_CHECK_MS)
    }
}
