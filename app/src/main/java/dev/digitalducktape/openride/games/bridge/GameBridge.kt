package dev.digitalducktape.openride.games.bridge

import dev.digitalducktape.openride.core.sensor.BikeDataSource
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.flow.StateFlow

/** Kotlin → Godot signals of the Bridge contract (v1 plus the hub's v1.1). JSON arguments are JSON text. */
interface GameSignals {
    fun sessionStarted(planJson: String)
    fun segmentStarted(segmentJson: String)
    fun segmentEnding()
    fun sessionPaused()
    fun sessionResumed()
    fun calibrationProgress(progress: CalibrationProgressSignal)
    fun sessionFinished(summaryJson: String)

    // v1.1, the Games hub (spec §3.1).
    fun hubState(stateJson: String)
    fun planRejected(reasonJson: String)
    fun visitEnded(resultJson: String)
}

/**
 * The Kotlin side of one game session: answers the contract's Godot → Kotlin methods and owns
 * the session clock: [dev.digitalducktape.openride.games.session.GameSessionManager].
 *
 * The bridge calls these on Godot's thread; implementations hand off to their own.
 */
interface GameSession {
    /** Input frame index 10: gameplay seconds left in the current segment, -1 if open-ended or none. */
    val segmentTimeLeftSec: Double

    /** Godot is running and polling frames, so its signal handlers are connected: start the session. */
    fun onGameReady()

    fun onSegmentFinished(resultJson: String)
    fun onRequestCalibration(mode: String)
    fun onSetTrackerMode(mode: String)
    fun onRequestPause()
    fun onRequestResume()
    fun onRequestEnd()
    fun onRequestExit()

    // v1.1, the Games hub (spec §3.3). Defaults ignore them, for sessions without a hub.

    /** `start_plan(request_json)`: valid in the hub only. */
    fun onStartPlan(requestJson: String) {}

    /** `update_setting(key, value_json)`. */
    fun onUpdateSetting(key: String, valueJson: String) {}

    /** `hub_calibrate(mode, full)`. */
    fun onHubCalibrate(mode: String, full: Boolean) {}

    fun onCancelCalibration() {}

    fun onRequestCameraPermission() {}

    /** `exit_hub(next)`: `app` or `edit_profile`. */
    fun onExitHub(next: String) {}

    /** The rider touched the hub (at most once a minute): resets the idle guard. */
    fun onHubActivity() {}
}

/**
 * App-scoped hub between the Godot plugin ([OpenRideBridgePlugin]) and whichever [GameSession]
 * the current `GameHostActivity` attached.
 *
 * App-scoped because Godot runs one engine per process and registers host plugins only on its
 * first start: after leaving and re-entering games, GDScript still talks to the first plugin
 * instance, so everything per-session lives here behind [attach]/[detach], never in the plugin.
 *
 * Readiness is implicit, so the contract needs no extra method: Godot connects its signal
 * handlers in the autoloads' `_ready`, before the first frame, so the first `get_input_frame()`
 * poll after [attach] is when the session may start sending signals ([GameSession.onGameReady]).
 */
class GameBridge(
    private val bikeDataSource: BikeDataSource,
    private val heartRateBpm: StateFlow<Int?>,
    /** Head-tracker fields 6-9: the camera tracker's latest snapshot (see [toTrackerReading]). */
    private val trackerReading: () -> TrackerReading = { TrackerReading.OFF },
) : GameSignals {
    @Volatile
    private var session: GameSession? = null
    private val readyPending = AtomicBoolean(false)

    /** Godot's side of the signals: the registered plugin, once the engine has started. */
    @Volatile
    var emitter: GameSignals? = null

    fun attach(session: GameSession) {
        this.session = session
        readyPending.set(true)
    }

    /** Detaches [session] if it is still the current one (a newer host may already have attached). */
    fun detach(session: GameSession) {
        if (this.session === session) {
            this.session = null
            readyPending.set(false)
        }
    }

    // --- Godot → Kotlin (called on Godot's thread) ---

    fun inputFrame(): DoubleArray {
        val current = session
        if (current != null && readyPending.compareAndSet(true, false)) current.onGameReady()
        return InputFrame.pack(
            metrics = bikeDataSource.metrics.value,
            connection = bikeDataSource.connectionState.value,
            heartRateBpm = heartRateBpm.value,
            tracker = trackerReading(),
            segmentTimeLeftSec = current?.segmentTimeLeftSec ?: -1.0,
        )
    }

    fun segmentFinished(resultJson: String) { session?.onSegmentFinished(resultJson) }
    fun requestCalibration(mode: String) { session?.onRequestCalibration(mode) }
    fun setTrackerMode(mode: String) { session?.onSetTrackerMode(mode) }
    fun requestPause() { session?.onRequestPause() }
    fun requestResume() { session?.onRequestResume() }
    fun requestEnd() { session?.onRequestEnd() }
    fun requestExit() { session?.onRequestExit() }
    fun startPlan(requestJson: String) { session?.onStartPlan(requestJson) }
    fun updateSetting(key: String, valueJson: String) { session?.onUpdateSetting(key, valueJson) }
    fun hubCalibrate(mode: String, full: Boolean) { session?.onHubCalibrate(mode, full) }
    fun cancelCalibration() { session?.onCancelCalibration() }
    fun requestCameraPermission() { session?.onRequestCameraPermission() }
    fun exitHub(next: String) { session?.onExitHub(next) }
    fun hubActivity() { session?.onHubActivity() }

    // --- Kotlin → Godot ---

    override fun sessionStarted(planJson: String) { emitter?.sessionStarted(planJson) }
    override fun segmentStarted(segmentJson: String) { emitter?.segmentStarted(segmentJson) }
    override fun segmentEnding() { emitter?.segmentEnding() }
    override fun sessionPaused() { emitter?.sessionPaused() }
    override fun sessionResumed() { emitter?.sessionResumed() }
    override fun calibrationProgress(progress: CalibrationProgressSignal) { emitter?.calibrationProgress(progress) }
    override fun sessionFinished(summaryJson: String) { emitter?.sessionFinished(summaryJson) }
    override fun hubState(stateJson: String) { emitter?.hubState(stateJson) }
    override fun planRejected(reasonJson: String) { emitter?.planRejected(reasonJson) }
    override fun visitEnded(resultJson: String) { emitter?.visitEnded(resultJson) }
}
