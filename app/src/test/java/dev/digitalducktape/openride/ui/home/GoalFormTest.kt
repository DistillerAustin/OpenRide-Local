package dev.digitalducktape.openride.ui.home

import dev.digitalducktape.openride.core.ride.RideGoal
import org.junit.Assert.assertEquals
import org.junit.Test

class GoalFormTest {

    @Test
    fun `the dialog opens on the current goal`() {
        assertEquals(GoalKind.None, GoalForm.kindOf(RideGoal.None))
        assertEquals(GoalKind.Duration, GoalForm.kindOf(RideGoal.Duration(1800)))
        assertEquals("30", GoalForm.initialMinutes(RideGoal.Duration(1800)))
        assertEquals("", GoalForm.initialMinutes(RideGoal.None))
        assertEquals(GoalKind.Output, GoalForm.kindOf(RideGoal.Output(300.0)))
        assertEquals("300.0", GoalForm.initialKj(RideGoal.Output(300.0)))
    }

    @Test
    fun `valid numbers become goals`() {
        assertEquals(RideGoal.Duration(30 * 60), GoalForm.toGoal(GoalKind.Duration, " 30 ", ""))
        assertEquals(RideGoal.Output(250.5), GoalForm.toGoal(GoalKind.Output, "", "250.5"))
        assertEquals(RideGoal.None, GoalForm.toGoal(GoalKind.None, "30", "250"))
    }

    @Test
    fun `blank, zero or junk input falls back to no goal`() {
        assertEquals(RideGoal.None, GoalForm.toGoal(GoalKind.Duration, "", ""))
        assertEquals(RideGoal.None, GoalForm.toGoal(GoalKind.Duration, "0", ""))
        assertEquals(RideGoal.None, GoalForm.toGoal(GoalKind.Duration, "abc", ""))
        assertEquals(RideGoal.None, GoalForm.toGoal(GoalKind.Output, "", "-5"))
    }
}
