package dev.digitalducktape.openride.ui.ride

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.games.session.GameLabels
import dev.digitalducktape.openride.ui.common.ExportShare
import dev.digitalducktape.openride.ui.common.GameBadge
import dev.digitalducktape.openride.ui.common.TimeFormat
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrAccentButton
import dev.digitalducktape.openride.ui.designsystem.component.OrChip
import dev.digitalducktape.openride.ui.designsystem.component.OrEyebrow
import dev.digitalducktape.openride.ui.designsystem.component.OrLabel
import dev.digitalducktape.openride.ui.designsystem.component.OrPrimaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSecondaryButton
import dev.digitalducktape.openride.ui.theme.MetricTextStyles
import kotlinx.coroutines.launch


/**
 * Post-ride summary and history detail (PRD P0-5, v2 metrics spec): a metric tab row
 * (Output / Cadence / Resistance / Heart-Rate-when-recorded) selecting which per-second
 * series the graph draws and which headline stats sit above it — after the original bike
 * UI's per-ride view. Reused unmodified as history's detail view (T8) — [viewModel] loads
 * by ride id from Room either way, so this screen never needs to know whether it's showing
 * a ride just stopped or one from history.
 */
@Composable
fun RideSummaryScreen(
    viewModel: RideSummaryViewModel,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val ride by viewModel.ride.collectAsState()
    val samples by viewModel.samples.collectAsState()
    val suggestedFtp by viewModel.suggestedFtp.collectAsState()
    val ftpApplied by viewModel.ftpApplied.collectAsState()
    val gameBadge by viewModel.gameBadge.collectAsState()
    val gameResults by viewModel.gameResults.collectAsState()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var selectedMetric by remember { mutableStateOf(RideMetric.Output) }

    LaunchedEffect(Unit) { viewModel.load() }

    // One screen, no scrolling (the rider's ask, 2026-10-21): a header with the actions, then
    // the selected metric's graph filling the left and, when there is any, the games and the
    // FTP suggestion on the right. Only a very long circuit's game list scrolls, inside its column.
    Surface(modifier = modifier.fillMaxSize(), color = OrColors.Background) {
        val current = ride
        if (current == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "Loading…", style = OrType.Body, color = OrColors.OnSurfaceMuted)
            }
            return@Surface
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = OrSpacing.ScreenGutter, vertical = OrSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(OrSpacing.md),
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(OrSpacing.md)) {
                        OrLabel(text = "Ride complete", style = OrType.ScreenTitle, color = OrColors.OnBackground)
                        gameBadge?.let { GameBadge(it) }
                    }
                    OrLabel(
                        text = "${TimeFormat.elapsed(current.durationSec)} · " +
                            (current.calories?.let { "$it kcal" } ?: "%.0f kJ".format(current.outputKj)),
                        style = OrType.Body,
                        color = OrColors.OnSurfaceMuted,
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(OrSpacing.md), verticalAlignment = Alignment.CenterVertically) {
                    OrSecondaryButton(text = "Export TCX", onClick = {
                        viewModel.tcxContent()?.let { tcx ->
                            ExportShare.share(context, "ride_${current.id}.tcx", tcx, "application/vnd.garmin.tcx+xml")
                        }
                    })
                    OrSecondaryButton(text = "Export CSV", onClick = {
                        viewModel.sampleCsvContent()?.let { csv ->
                            ExportShare.share(context, "ride_${current.id}.csv", csv, "text/csv")
                        }
                    })
                    OrPrimaryButton(text = "Done", onClick = {
                        viewModel.dismiss()
                        onDismiss()
                    })
                }
            }

            Row(modifier = Modifier.fillMaxWidth().weight(1f), horizontalArrangement = Arrangement.spacedBy(OrSpacing.xl)) {
                Column(modifier = Modifier.weight(3f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(OrSpacing.md)) {
                    MetricTabRow(
                        metrics = RideMetric.available(samples),
                        selected = selectedMetric,
                        onSelect = { selectedMetric = it },
                    )
                    StatBand(stats = RideMetricStats.stats(selectedMetric, current, samples), modifier = Modifier.fillMaxWidth())
                    MetricGraph(
                        points = RideMetricStats.points(selectedMetric, samples),
                        modifier = Modifier.fillMaxWidth().weight(1f),
                    )
                }
                if (gameResults.isNotEmpty() || suggestedFtp != null) {
                    Column(modifier = Modifier.weight(2f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(OrSpacing.lg)) {
                        if (gameResults.isNotEmpty()) {
                            GameResultsList(rows = gameResults, modifier = Modifier.fillMaxWidth().weight(1f, fill = false))
                        }
                        suggestedFtp?.let { ftp ->
                            FtpSuggestionCard(
                                suggestedFtp = ftp,
                                applied = ftpApplied,
                                onApply = { scope.launch { viewModel.applySuggestedFtp() } },
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }
        }
    }
}

/** A game session's segments (#35): each game, its role and difficulty, score and stars. */
@Composable
private fun GameResultsList(rows: List<GameLabels.ResultRow>, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(OrSpacing.sm)) {
        OrEyebrow(text = "Games")
        LazyColumn(verticalArrangement = Arrangement.spacedBy(OrSpacing.sm)) {
            items(rows) { row ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(color = OrColors.Surface, shape = OrShapes.Small)
                        .padding(horizontal = OrSpacing.md, vertical = OrSpacing.sm + OrSpacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        OrLabel(text = row.title, style = OrType.Subtitle, color = OrColors.OnBackground)
                        OrLabel(text = row.detail, style = OrType.Caption, color = OrColors.OnSurfaceMuted)
                    }
                    if (!row.skipped) StarRating(stars = row.stars)
                }
            }
        }
    }
}

/**
 * 0–3 stars as icons: the tablet's font has no ★/☆ glyphs (they drew as boxes with an X, rider
 * bike test 2026-10-21). Earned stars in the accent, the rest dimmed.
 */
@Composable
private fun StarRating(stars: Int, modifier: Modifier = Modifier) {
    Row(modifier = modifier.semantics { contentDescription = "$stars of 3 stars" }) {
        repeat(3) { i ->
            Icon(
                imageVector = Icons.Filled.Star,
                contentDescription = null,
                tint = if (i < stars) OrColors.Accent else OrColors.Outline,
                modifier = Modifier.size(OrSize.NavIcon),
            )
        }
    }
}

/**
 * Shown once a ride's per-second series spans at least 20 minutes (PRD P1-3): 95% of the
 * ride's best 20-minute average power, offered as an FTP update for the rider who logged it.
 */
@Composable
private fun FtpSuggestionCard(
    suggestedFtp: Int,
    applied: Boolean,
    onApply: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.background(OrColors.Surface, OrShapes.Small).padding(OrSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            OrLabel(text = "Estimated FTP: ${suggestedFtp} W", style = OrType.Subtitle, color = OrColors.OnBackground)
            Text(text = "95% of your best 20 minutes", style = OrType.Caption, color = OrColors.OnSurfaceMuted)
        }
        if (applied) {
            OrLabel(text = "FTP updated", style = OrType.Button, color = OrColors.Success)
        } else {
            OrAccentButton(text = "Update FTP", onClick = onApply)
        }
    }
}

/** Pill tab row selecting the graphed metric, after the original bike UI's tab strip. */
@Composable
private fun MetricTabRow(
    metrics: List<RideMetric>,
    selected: RideMetric,
    onSelect: (RideMetric) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(OrSpacing.sm)) {
        metrics.forEach { metric ->
            OrChip(text = metric.label, selected = metric == selected, onClick = { onSelect(metric) })
        }
    }
}

/** TOTAL / AVG / MAX headline stats for the selected metric. */
@Composable
private fun StatBand(stats: List<MetricStat>, modifier: Modifier = Modifier) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(48.dp)) {
        stats.forEach { stat ->
            Column {
                Text(
                    text = stat.label,
                    style = MetricTextStyles.TileLabel,
                    color = OrColors.Accent,
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = stat.value,
                        style = MetricTextStyles.TileValueLarge,
                        color = OrColors.OnBackground,
                    )
                    Text(
                        text = stat.unit,
                        style = MetricTextStyles.UnitLabel,
                        color = OrColors.OnSurfaceMuted,
                        modifier = Modifier.padding(start = 6.dp, bottom = 10.dp),
                    )
                }
            }
        }
    }
}
