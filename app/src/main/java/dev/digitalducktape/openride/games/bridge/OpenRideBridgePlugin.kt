package dev.digitalducktape.openride.games.bridge

import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * The `OpenRideBridge` engine singleton (Bridge contract v1 plus the hub's v1.1, docs/GAMES.md), registered by
 * `GameHostActivity` as a host plugin. GDScript reaches it only through the `InputBus` and
 * `Session` autoloads, as `Engine.get_singleton("OpenRideBridge")`.
 *
 * A thin adapter: Godot keeps this first instance for the life of the process, so all state
 * lives in the app-scoped [GameBridge]. Method names are the contract's snake_case names,
 * because GDScript calls them by their JVM name.
 */
@Suppress("FunctionName")
class OpenRideBridgePlugin(godot: Godot, private val bridge: GameBridge) : GodotPlugin(godot), GameSignals {
    init {
        bridge.emitter = this
    }

    override fun getPluginName() = NAME

    override fun getPluginSignals(): Set<SignalInfo> = SIGNALS

    // --- Godot → Kotlin methods ---

    /** The v1 input frame ([InputFrame]); arrives in GDScript as a `PackedFloat64Array`. */
    @UsedByGodot
    fun get_input_frame(): DoubleArray = bridge.inputFrame()

    @UsedByGodot
    fun segment_finished(resultJson: String) = bridge.segmentFinished(resultJson)

    @UsedByGodot
    fun request_calibration(mode: String) = bridge.requestCalibration(mode)

    @UsedByGodot
    fun set_tracker_mode(mode: String) = bridge.setTrackerMode(mode)

    @UsedByGodot
    fun request_pause() = bridge.requestPause()

    @UsedByGodot
    fun request_resume() = bridge.requestResume()

    @UsedByGodot
    fun request_end() = bridge.requestEnd()

    @UsedByGodot
    fun request_exit() = bridge.requestExit()

    // v1.1, the Games hub.

    @UsedByGodot
    fun start_plan(requestJson: String) = bridge.startPlan(requestJson)

    @UsedByGodot
    fun update_setting(key: String, valueJson: String) = bridge.updateSetting(key, valueJson)

    @UsedByGodot
    fun hub_calibrate(mode: String, full: Boolean) = bridge.hubCalibrate(mode, full)

    @UsedByGodot
    fun cancel_calibration() = bridge.cancelCalibration()

    @UsedByGodot
    fun request_camera_permission() = bridge.requestCameraPermission()

    @UsedByGodot
    fun exit_hub(next: String) = bridge.exitHub(next)

    /**
     * v1.2: covers the engine's view with the host's native loading screen while a game starts.
     * Its first 3D frame compiles shaders for seconds on the bike, with the GL thread blocked;
     * the overlay lives on the UI thread, so it keeps animating meanwhile.
     */
    @UsedByGodot
    fun show_loading(show: Boolean) {
        val host = activity as? GameLoadingHost ?: return
        activity?.runOnUiThread { host.setGameLoading(show) }
    }

    @UsedByGodot
    fun hub_activity() = bridge.hubActivity()

    /** v1.3: the hub's music card: `play_pause`, `next` or `previous` for the rider's music app. */
    @UsedByGodot
    fun music_control(action: String) = bridge.musicControl(action)

    // --- Kotlin → Godot signals (GodotPlugin queues them onto Godot's thread) ---

    override fun sessionStarted(planJson: String) = emitSignal(SESSION_STARTED.name, planJson)
    override fun segmentStarted(segmentJson: String) = emitSignal(SEGMENT_STARTED.name, segmentJson)
    override fun segmentEnding() = emitSignal(SEGMENT_ENDING.name)
    override fun sessionPaused() = emitSignal(SESSION_PAUSED.name)
    override fun sessionResumed() = emitSignal(SESSION_RESUMED.name)
    override fun calibrationProgress(progress: CalibrationProgressSignal) = emitSignal(
        CALIBRATION_PROGRESS.name,
        progress.step,
        progress.fraction,
        progress.stepIndex,
        progress.stepCount,
        progress.attempt,
        progress.retryReason,
    )
    override fun sessionFinished(summaryJson: String) = emitSignal(SESSION_FINISHED.name, summaryJson)
    override fun hubState(stateJson: String) = emitSignal(HUB_STATE.name, stateJson)
    override fun planRejected(reasonJson: String) = emitSignal(PLAN_REJECTED.name, reasonJson)
    override fun visitEnded(resultJson: String) = emitSignal(VISIT_ENDED.name, resultJson)
    override fun nowPlaying(nowPlayingJson: String) = emitSignal(NOW_PLAYING.name, nowPlayingJson)

    companion object {
        const val NAME = "OpenRideBridge"

        private val SESSION_STARTED = SignalInfo("session_started", String::class.java)
        private val SEGMENT_STARTED = SignalInfo("segment_started", String::class.java)
        private val SEGMENT_ENDING = SignalInfo("segment_ending")
        private val SESSION_PAUSED = SignalInfo("session_paused")
        private val SESSION_RESUMED = SignalInfo("session_resumed")
        private val CALIBRATION_PROGRESS = SignalInfo(
            "calibration_progress",
            String::class.java, // step
            Double::class.javaObjectType, // fraction
            Int::class.javaObjectType, // step_index
            Int::class.javaObjectType, // step_count
            Int::class.javaObjectType, // attempt
            String::class.java, // retry_reason
        )
        private val SESSION_FINISHED = SignalInfo("session_finished", String::class.java)
        private val HUB_STATE = SignalInfo("hub_state", String::class.java)
        private val PLAN_REJECTED = SignalInfo("plan_rejected", String::class.java)
        private val VISIT_ENDED = SignalInfo("visit_ended", String::class.java)
        private val NOW_PLAYING = SignalInfo("now_playing", String::class.java)

        private val SIGNALS = setOf(
            SESSION_STARTED, SEGMENT_STARTED, SEGMENT_ENDING, SESSION_PAUSED, SESSION_RESUMED,
            CALIBRATION_PROGRESS, SESSION_FINISHED, HUB_STATE, PLAN_REJECTED, VISIT_ENDED, NOW_PLAYING,
        )
    }
}

/** The activity hosting the engine, which owns the native loading screen ([OpenRideBridgePlugin.show_loading]). */
interface GameLoadingHost {
    fun setGameLoading(loading: Boolean)
}
