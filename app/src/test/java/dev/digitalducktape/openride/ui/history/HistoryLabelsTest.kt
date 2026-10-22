package dev.digitalducktape.openride.ui.history

import dev.digitalducktape.openride.ui.designsystem.component.OrStatValue
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryLabelsTest {

    private val stats = HistoryStats(
        totalRides = 3,
        totalDurationSec = 7_672,
        totalOutputKj = 1_247.5,
        bestOutputKj = 655.1,
        bestAvgPower = 174,
        longestRideSec = 3_760,
    )

    @Test
    fun `lifetime band shows rides, time and whole kJ`() {
        assertEquals(
            listOf(
                OrStatValue("Total rides", "3"),
                OrStatValue("Total time", "2:07:52"),
                OrStatValue("Total output", "1248", "kJ"),
            ),
            HistoryLabels.lifetime(stats),
        )
    }

    @Test
    fun `records band shows best ride, best average and longest ride`() {
        assertEquals(
            listOf(
                OrStatValue("Best ride", "655", "kJ"),
                OrStatValue("Best avg", "174", "watts"),
                OrStatValue("Longest", "1:02:40"),
            ),
            HistoryLabels.records(stats),
        )
    }

    @Test
    fun `records with no rides read as zero rather than blank`() {
        val empty = HistoryStats.from(emptyList())
        assertEquals(listOf("0", "0", "00:00"), HistoryLabels.records(empty).map { it.value })
    }

    @Test
    fun `calendar weeks are Monday first, padded to seven, blanks outside the month`() {
        // October 2026 starts on a Thursday and has 31 days: 3 blanks, then 5 weeks.
        val weeks = CalendarGrid.weeks(YearMonth.of(2026, 10))
        assertEquals(5, weeks.size)
        assertTrue(weeks.all { it.size == 7 })
        assertEquals(listOf(null, null, null), weeks.first().take(3))
        assertEquals(LocalDate.of(2026, 10, 1), weeks.first()[3])
        assertEquals(DayOfWeek.THURSDAY, weeks.first()[3]!!.dayOfWeek)
        assertEquals(LocalDate.of(2026, 10, 31), weeks.last()[5])
        assertNull(weeks.last()[6])
        assertEquals(31, weeks.flatten().count { it != null })
    }

    @Test
    fun `a month that starts on Monday and fills four weeks has no blanks`() {
        val weeks = CalendarGrid.weeks(YearMonth.of(2021, 2))
        assertEquals(4, weeks.size)
        assertTrue(weeks.flatten().none { it == null })
    }

    @Test
    fun `a month that needs six rows gets six`() {
        // August 2026 starts on a Saturday: 5 blanks + 31 days = 36 cells.
        assertEquals(6, CalendarGrid.weeks(YearMonth.of(2026, 8)).size)
    }
}
