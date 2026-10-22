package dev.digitalducktape.openride.games.session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VisitNavigatorTest {
    private val navigator = VisitNavigator()

    @Test
    fun `a saved visit opens its ride summary, once`() {
        navigator.visitEnded(rideId = 42, next = "app")

        val destination = navigator.pending.value
        assertEquals(VisitDestination.RideSummary(42), destination)
        navigator.consume(destination!!)
        assertNull(navigator.pending.value)
    }

    @Test
    fun `the FTP nudge opens the profile editor, even when a ride was saved`() {
        navigator.visitEnded(rideId = 42, next = "edit_profile")

        assertEquals(VisitDestination.EditProfile, navigator.pending.value)
    }

    @Test
    fun `nothing saved, or still in the hub, goes nowhere`() {
        navigator.visitEnded(rideId = null, next = "app")
        assertNull(navigator.pending.value)
        navigator.visitEnded(rideId = 7, next = "hub") // the idle guard: the rider is still in games
        assertNull(navigator.pending.value)
    }

    @Test
    fun `consuming a destination that was already replaced keeps the newer one`() {
        navigator.visitEnded(rideId = 1, next = "app")
        val old = navigator.pending.value!!
        navigator.visitEnded(rideId = 2, next = "app")

        navigator.consume(old)

        assertEquals(VisitDestination.RideSummary(2), navigator.pending.value)
    }
}
