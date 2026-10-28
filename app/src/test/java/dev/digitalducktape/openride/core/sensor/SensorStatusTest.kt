package dev.digitalducktape.openride.core.sensor

import app.cash.turbine.test
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/** Issue #56: the sensors-offline notice shows after 10 s of silence, never for a blip, and clears at once. */
class SensorStatusTest {

    @Test
    fun `offline is reported only after the delay, and online at once`() = runTest {
        val state = MutableStateFlow<ConnectionState>(ConnectionState.Connected)
        state.offlineFor(10.seconds).test {
            assertEquals(false, awaitItem())
            state.value = ConnectionState.Disconnected
            advanceTimeBy(9_999)
            expectNoEvents()
            advanceTimeBy(2)
            assertEquals(true, awaitItem())
            state.value = ConnectionState.Connected
            assertEquals(false, awaitItem())
        }
    }

    @Test
    fun `a blip shorter than the delay never shows`() = runTest {
        val state = MutableStateFlow<ConnectionState>(ConnectionState.Connected)
        state.offlineFor(10.seconds).test {
            assertEquals(false, awaitItem())
            state.value = ConnectionState.Disconnected
            advanceTimeBy(5_000)
            state.value = ConnectionState.Connected
            advanceTimeBy(20_000)
            expectNoEvents()
        }
    }

    @Test
    fun `a source that never connects is reported after the delay`() = runTest {
        val state = MutableStateFlow<ConnectionState>(ConnectionState.Unavailable)
        state.offlineFor(10.seconds).test {
            expectNoEvents()
            advanceTimeBy(10_001)
            assertEquals(true, awaitItem())
        }
    }

    @Test
    fun `watchFrames passes the link state through while frames flow`() = runTest {
        val link = MutableStateFlow<ConnectionState>(ConnectionState.Connected)
        val out = MutableStateFlow<ConnectionState>(ConnectionState.Unavailable)
        var frames = 0L
        backgroundScope.launch { while (true) { frames++; delay(50) } }
        backgroundScope.watchFrames(link, { frames }, out)
        advanceTimeBy(10_000)
        assertEquals(ConnectionState.Connected, out.value)
        link.value = ConnectionState.Unavailable
        advanceTimeBy(300)
        assertEquals(ConnectionState.Unavailable, out.value)
    }

    @Test
    fun `watchFrames reads a silent Connected link as Disconnected until frames return`() = runTest {
        val link = MutableStateFlow<ConnectionState>(ConnectionState.Connected)
        val out = MutableStateFlow<ConnectionState>(ConnectionState.Connected)
        var frames = 0L
        backgroundScope.watchFrames(link, { frames }, out)
        advanceTimeBy(SENSOR_SILENT_AFTER_MS - 300)
        assertEquals(ConnectionState.Connected, out.value)
        advanceTimeBy(600)
        assertEquals(ConnectionState.Disconnected, out.value)
        frames++
        advanceTimeBy(300)
        assertEquals(ConnectionState.Connected, out.value)
    }

    @Test
    fun `a silent board shows offline through the shared rule`() = runTest {
        val link = MutableStateFlow<ConnectionState>(ConnectionState.Connected)
        val state = MutableStateFlow<ConnectionState>(ConnectionState.Connected)
        backgroundScope.watchFrames(link, { 0L }, state)
        state.offlineFor(10.seconds).test {
            assertEquals(false, awaitItem())
            advanceTimeBy(SENSOR_SILENT_AFTER_MS + 10_300)
            assertEquals(true, awaitItem())
        }
    }
}
