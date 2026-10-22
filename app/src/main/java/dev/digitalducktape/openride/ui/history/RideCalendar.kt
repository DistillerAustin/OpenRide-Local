package dev.digitalducktape.openride.ui.history

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrEyebrow
import dev.digitalducktape.openride.ui.designsystem.component.OrIconButton
import dev.digitalducktape.openride.ui.designsystem.component.OrLabel
import dev.digitalducktape.openride.ui.theme.OpenRideTheme
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

/**
 * Month calendar with ride days marked (v2 metrics spec): a Monday-first grid ([CalendarGrid]),
 * accent-filled circles on days with a ride, an accent ring on today, and previous/next month
 * buttons at the touch minimum in the header.
 */
@Composable
fun RideCalendar(
    month: YearMonth,
    rideDates: Set<LocalDate>,
    onMonthChange: (YearMonth) -> Unit,
    modifier: Modifier = Modifier,
    today: LocalDate = LocalDate.now(),
) {
    Column(modifier = modifier) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            OrIconButton(
                icon = OrIcons.Chevron,
                contentDescription = "Previous month",
                onClick = { onMonthChange(month.minusMonths(1)) },
                iconModifier = Modifier.rotate(180f),
            )
            Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                OrLabel(text = month.format(MonthFormatter), style = OrType.Subtitle, color = OrColors.OnBackground)
            }
            OrIconButton(
                icon = OrIcons.Chevron,
                contentDescription = "Next month",
                onClick = { onMonthChange(month.plusMonths(1)) },
            )
        }

        Row(modifier = Modifier.fillMaxWidth().padding(top = OrSpacing.sm)) {
            for (label in DayLabels) {
                Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    OrEyebrow(text = label)
                }
            }
        }

        CalendarGrid.weeks(month).forEach { week ->
            Row(modifier = Modifier.fillMaxWidth().padding(top = OrSpacing.xs)) {
                week.forEach { day ->
                    DayCell(
                        day = day,
                        hasRide = day != null && day in rideDates,
                        isToday = day == today,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

private val MonthFormatter = DateTimeFormatter.ofPattern("MMMM yyyy")
private val DayLabels = listOf("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")
private val DaySize = 32.dp

@Composable
private fun DayCell(day: LocalDate?, hasRide: Boolean, isToday: Boolean, modifier: Modifier = Modifier) {
    Box(modifier = modifier.height(DaySize), contentAlignment = Alignment.Center) {
        if (day != null) {
            val ring = if (isToday && !hasRide) Modifier.border(2.dp, OrColors.Accent, CircleShape) else Modifier
            Box(
                modifier = Modifier
                    .size(DaySize)
                    .background(color = if (hasRide) OrColors.Accent else Color.Transparent, shape = CircleShape)
                    .then(ring),
                contentAlignment = Alignment.Center,
            ) {
                OrLabel(
                    text = "${day.dayOfMonth}",
                    style = if (hasRide || isToday) OrType.Caption.copy(fontWeight = FontWeight.Bold) else OrType.Caption,
                    color = when {
                        hasRide -> OrColors.OnAccent
                        isToday -> OrColors.Accent
                        else -> OrColors.OnSurfaceMuted
                    },
                )
            }
        }
    }
}

@ComponentPreview
@Composable
private fun RideCalendarPreview() {
    OpenRideTheme {
        RideCalendar(
            month = YearMonth.of(2026, 10),
            rideDates = setOf(LocalDate.of(2026, 10, 3), LocalDate.of(2026, 10, 19), LocalDate.of(2026, 10, 20)),
            onMonthChange = {},
            today = LocalDate.of(2026, 10, 21),
            modifier = Modifier.size(width = 560.dp, height = 340.dp).padding(OrSpacing.md),
        )
    }
}
