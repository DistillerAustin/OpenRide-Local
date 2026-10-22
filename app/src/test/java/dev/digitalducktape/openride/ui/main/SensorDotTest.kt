package dev.digitalducktape.openride.ui.main

import org.junit.Assert.assertEquals
import org.junit.Test

/** The top bar's sensor dot never claims "connected" before the offline check has answered. */
class SensorDotTest {

    @Test
    fun `no answer yet is checking, not connected`() {
        assertEquals(SensorDot.Checking, SensorDot.of(null))
    }

    @Test
    fun `answers map to connected and offline`() {
        assertEquals(SensorDot.Connected, SensorDot.of(false))
        assertEquals(SensorDot.Offline, SensorDot.of(true))
    }
}
