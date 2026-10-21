package dev.digitalducktape.openride.core.sensor

import app.cash.turbine.test
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.flow.MutableStateFlow
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
}
