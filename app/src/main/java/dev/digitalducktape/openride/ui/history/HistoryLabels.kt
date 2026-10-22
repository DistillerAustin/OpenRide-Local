package dev.digitalducktape.openride.ui.history

import dev.digitalducktape.openride.ui.common.TimeFormat
import dev.digitalducktape.openride.ui.designsystem.component.OrStatValue
import java.time.LocalDate
import java.time.YearMonth

/**
 * The History tab's display strings, worked out from [HistoryStats] (pure, plain-JUnit
 * testable): the lifetime band and the personal-records band, three numbers each.
 */
object HistoryLabels {
    fun lifetime(stats: HistoryStats): List<OrStatValue> = listOf(
        OrStatValue("Total rides", "${stats.totalRides}"),
        OrStatValue("Total time", TimeFormat.elapsed(stats.totalDurationSec.toInt())),
        OrStatValue("Total output", "%.0f".format(stats.totalOutputKj), "kJ"),
    )

    fun records(stats: HistoryStats): List<OrStatValue> = listOf(
        OrStatValue("Best ride", "%.0f".format(stats.bestOutputKj ?: 0.0), "kJ"),
        OrStatValue("Best avg", "${stats.bestAvgPower ?: 0}", "watts"),
        OrStatValue("Longest", TimeFormat.elapsed(stats.longestRideSec ?: 0)),
    )

    const val EMPTY_MESSAGE = "No rides yet. Finish a ride to see it here"
}

/** The calendar's grid for one month: Monday-first weeks of seven, `null` outside the month. */
object CalendarGrid {
    fun weeks(month: YearMonth): List<List<LocalDate?>> {
        val leadingBlanks = month.atDay(1).dayOfWeek.value - 1
        val cells: List<LocalDate?> = List(leadingBlanks) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
        return cells.chunked(7).map { week -> week + List(7 - week.size) { null } }
    }
}
