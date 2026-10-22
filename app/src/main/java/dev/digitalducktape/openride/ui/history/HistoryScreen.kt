package dev.digitalducktape.openride.ui.history

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.digitalducktape.openride.ui.common.GameBadge
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrEmptyState
import dev.digitalducktape.openride.ui.designsystem.component.OrListRow
import dev.digitalducktape.openride.ui.designsystem.component.OrStatBand
import dev.digitalducktape.openride.ui.designsystem.component.OrTile
import dev.digitalducktape.openride.ui.theme.OpenRideTheme
import java.time.LocalDate
import java.time.YearMonth

/**
 * History tab, connected to its [HistoryViewModel] (the Route half of the Route/Screen split).
 * Draws nothing until the rides are read, then everything at once, so "No rides yet" never
 * flashes before the list. Export CSV lives in the shared top bar (`MainScaffold`).
 */
@Composable
fun HistoryRoute(
    viewModel: HistoryViewModel,
    onRideSelected: (rideId: Long) -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val loaded = uiState ?: return
    HistoryScreen(uiState = loaded, onRideSelected = onRideSelected, modifier = modifier)
}

/**
 * History tab (PRD P0-5), stateless: the lifetime and personal-records bands across the top,
 * then the rides (newest first; tap one for its [dev.digitalducktape.openride.ui.ride.RideSummaryScreen])
 * on the left and the month calendar with ride days marked on the right. Only the ride list
 * scrolls. The list never touches per-ride samples, which keeps 100+ rows smooth.
 */
@Composable
fun HistoryScreen(
    uiState: HistoryUiState,
    onRideSelected: (rideId: Long) -> Unit,
    modifier: Modifier = Modifier,
    today: LocalDate = LocalDate.now(),
) {
    var month by rememberSaveable { mutableStateOf(YearMonth.from(today)) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, top = OrSpacing.sm, bottom = OrSpacing.lg),
        verticalArrangement = Arrangement.spacedBy(OrSpacing.lg),
    ) {
        if (uiState.rows.isEmpty()) {
            OrEmptyState(message = HistoryLabels.EMPTY_MESSAGE)
            return@Column
        }

        Row(horizontalArrangement = Arrangement.spacedBy(OrSpacing.xxl)) {
            OrStatBand(title = "Lifetime", stats = HistoryLabels.lifetime(uiState.stats))
            OrStatBand(title = "Personal records", stats = HistoryLabels.records(uiState.stats))
        }

        Row(
            modifier = Modifier.fillMaxWidth().weight(1f),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.lg),
        ) {
            LazyColumn(
                modifier = Modifier.weight(1f).fillMaxHeight(),
                verticalArrangement = Arrangement.spacedBy(OrSpacing.sm),
                contentPadding = PaddingValues(bottom = OrSpacing.sm),
            ) {
                items(uiState.rows, key = { it.rideId }) { row ->
                    RideRow(row = row, onClick = { onRideSelected(row.rideId) })
                }
            }
            OrTile(
                modifier = Modifier.weight(1f).fillMaxHeight(),
                contentPadding = PaddingValues(horizontal = OrSpacing.lg, vertical = OrSpacing.md),
            ) {
                RideCalendar(
                    month = month,
                    rideDates = uiState.rideDates,
                    onMonthChange = { month = it },
                    today = today,
                )
            }
        }
    }
}

@Composable
private fun RideRow(row: RideHistoryRow, onClick: () -> Unit) {
    OrListRow(
        onClick = onClick,
        trailing = {
            Text(text = row.outputKjLabel, style = OrType.Subtitle, color = OrColors.OnBackground)
            Text(text = row.avgCadenceLabel, style = OrType.Caption, color = OrColors.OnSurfaceMuted)
        },
    ) {
        Text(text = row.dateLabel, style = OrType.Subtitle, color = OrColors.OnBackground)
        Text(text = row.durationLabel, style = OrType.Caption, color = OrColors.OnSurfaceMuted)
        row.gameBadge?.let { GameBadge(it, modifier = Modifier.padding(top = OrSpacing.xs)) }
    }
}

@BikePreview
@Composable
private fun HistoryScreenPreview() {
    val today = LocalDate.of(2026, 10, 21)
    OpenRideTheme {
        HistoryScreen(
            uiState = HistoryUiState(
                rows = listOf(
                    RideHistoryRow(3, "Oct 21, 2026", "45:12", "412.0 kJ", "84 rpm avg"),
                    RideHistoryRow(2, "Oct 20, 2026", "20:00", "180.4 kJ", "78 rpm avg", gameBadge = "Demo · 20 min"),
                    RideHistoryRow(1, "Oct 3, 2026", "1:02:40", "655.1 kJ", "88 rpm avg"),
                ),
                stats = HistoryStats(3, 7672, 1247.5, 655.1, 174, 3760),
                rideDates = setOf(LocalDate.of(2026, 10, 3), LocalDate.of(2026, 10, 20), today),
            ),
            onRideSelected = {},
            today = today,
        )
    }
}
