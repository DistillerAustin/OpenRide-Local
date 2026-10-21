package dev.digitalducktape.openride.ui.home

import dev.digitalducktape.openride.core.data.Profile
import dev.digitalducktape.openride.core.ride.RideGoal
import org.junit.Assert.assertEquals
import org.junit.Test

class HomeUiStateTest {

    private val rider = Profile(name = "Ed", avatarEmoji = "🚴", avatarColor = 0, weightKg = null, ftp = null)

    @Test
    fun `greets the active rider by name, or Rider while none is loaded`() {
        assertEquals("Ed", HomeUiState(profile = rider).riderName)
        assertEquals("Rider", HomeUiState().riderName)
    }

    @Test
    fun `with no goal the button offers to set one`() {
        val state = HomeUiState(goal = RideGoal.None)
        assertEquals("No goal set", state.goalLabel)
        assertEquals("Set goal", state.goalActionLabel)
    }

    @Test
    fun `a time goal reads in minutes and offers to change it`() {
        val state = HomeUiState(goal = RideGoal.Duration(targetSec = 30 * 60))
        assertEquals("Goal: 30 min", state.goalLabel)
        assertEquals("Change goal", state.goalActionLabel)
    }

    @Test
    fun `an output goal reads in whole kJ`() {
        assertEquals("Goal: 300 kJ", HomeUiState(goal = RideGoal.Output(targetKj = 300.0)).goalLabel)
    }
}
