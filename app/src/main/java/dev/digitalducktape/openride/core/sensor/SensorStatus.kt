package dev.digitalducktape.openride.core.sensor

import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.transformLatest

/** How long the sensors must stay away before the app says so (issue #56): a blip never shows. */
val SensorOfflineAfter: Duration = 10.seconds

/**
 * `true` once this connection has been anything but [ConnectionState.Connected] for [after]
 * without a break, and `false` again the moment it reconnects. Drives the shell's "sensors
 * offline" notice and the top bar's sensor dot (issue #56). Emits nothing until it knows: an
 * offline start stays silent for [after].
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
