package dev.digitalducktape.openride.debug

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import dev.digitalducktape.openride.appContainer
import dev.digitalducktape.openride.core.sensor.MockBikeDataSource

/**
 * Simulates a sensor fault on the mock build, so the "sensors offline" UI (issue #56) can be
 * checked on the bike without unplugging anything. Debug builds only; the real-sensor build
 * ignores it.
 *
 *   adb shell am broadcast -n dev.digitalducktape.openride/.debug.SensorFaultReceiver \
 *     --es fault silence --ei seconds 30
 *
 * `fault` is `silence` (the board goes quiet behind a live binding: no frames, link still up)
 * or `dropout` (the link drops); `seconds` defaults to 30.
 */
class SensorFaultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val mock = context.appContainer.bikeDataSource as? MockBikeDataSource
        if (mock == null) {
            Log.w(TAG, "not a mock build: sensor faults can't be simulated")
            return
        }
        val seconds = intent.getIntExtra("seconds", 30)
        when (val fault = intent.getStringExtra("fault") ?: "silence") {
            "silence" -> mock.simulateSilence(seconds)
            "dropout" -> mock.simulateDropout(seconds)
            else -> {
                Log.w(TAG, "unknown fault '$fault' (silence or dropout)")
                return
            }
        }
        Log.i(TAG, "simulating ${intent.getStringExtra("fault") ?: "silence"} for $seconds s")
    }

    private companion object {
        const val TAG = "SensorFault"
    }
}
