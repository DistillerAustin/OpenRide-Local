package dev.digitalducktape.openride.ui.ride

import dev.digitalducktape.openride.core.data.Ride
import dev.digitalducktape.openride.core.data.RideSample
import dev.digitalducktape.openride.games.session.GameLabels
import dev.digitalducktape.openride.ui.designsystem.component.OrStatValue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RideSummaryUiStateTest {

    private val ride = Ride(
        id = 1, profileId = 1, startEpochMs = 0, durationSec = 45 * 60 + 12, avgCadence = 80, maxCadence = 100,
        avgPower = 150, maxPower = 300, avgResistance = 40, outputKj = 412.4, calories = null,
    )

    @Test
    fun `subtitle prefers calories and falls back to whole kJ`() {
        assertEquals("45:12 · 412 kJ", RideSummaryUiState.subtitle(ride))
        assertEquals("45:12 · 380 kcal", RideSummaryUiState.subtitle(ride.copy(calories = 380)))
    }

    @Test
    fun `side column only when there are games or an FTP suggestion`() {
        assertFalse(RideSummaryUiState(ride = ride).hasSideColumn)
        assertTrue(RideSummaryUiState(ride = ride, suggestedFtp = 210).hasSideColumn)
        val game = GameLabels.ResultRow("Tug of War", "Work", 2, skipped = false)
        assertTrue(RideSummaryUiState(ride = ride, gameResults = listOf(game)).hasSideColumn)
    }

    @Test
    fun `heart rate tab only for rides that recorded it`() {
        val plain = RideSample(1, 0, 80, 40, 150)
        assertEquals(3, RideSummaryUiState(ride = ride, samples = listOf(plain)).metrics.size)
        val withHr = RideSummaryUiState(ride = ride, samples = listOf(plain.copy(heartRateBpm = 120)))
        assertEquals(RideMetric.HeartRate, withHr.metrics.last())
    }

    @Test
    fun `stats become stat values with their units`() {
        assertEquals(
            listOf(
                OrStatValue("TOTAL OUTPUT", "412", "KJ"),
                OrStatValue("AVG OUTPUT", "150", "WATTS"),
                OrStatValue("MAX OUTPUT", "300", "WATTS"),
            ),
            RideSummaryUiState.stats(RideMetric.Output, ride, emptyList()),
        )
    }

    @Test
    fun `graph axis rounds up to a friendly maximum`() {
        assertEquals(4, niceCeiling(0))
        assertEquals(500, niceCeiling(437))
        assertEquals(1000, niceCeiling(1000))
        assertEquals(1200, niceCeiling(1001))
    }
}
