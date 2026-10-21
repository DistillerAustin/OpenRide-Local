package dev.digitalducktape.openride.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.core.sensor.ConnectionState
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrLabel

/**
 * The bike's sensors in the top bar: a green dot while they report, amber once they have been
 * silent for `SensorOfflineAfter` (the notice under the bar says what to do).
 */
@Composable
fun SensorStatus(offline: Boolean, modifier: Modifier = Modifier) {
    val color = if (offline) OrColors.Warning else OrColors.Success
    Row(
        modifier = modifier.semantics { contentDescription = if (offline) "Bike sensors offline" else "Bike sensors connected" },
        horizontalArrangement = Arrangement.spacedBy(OrSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(12.dp).background(color, CircleShape))
        OrLabel(text = "Sensors", style = OrType.Caption, color = if (offline) OrColors.Warning else OrColors.OnSurfaceMuted)
    }
}

/**
 * The heart-rate strap in the top bar: the live bpm while connected, a muted "HR" while a paired
 * strap is out of reach, and nothing at all when the rider has no strap.
 */
@Composable
fun HeartRateStatus(paired: Boolean, state: ConnectionState, bpm: Int?, modifier: Modifier = Modifier) {
    if (!paired) return
    val live = state == ConnectionState.Connected && bpm != null
    val color = if (live) OrColors.Danger else OrColors.OnSurfaceMuted
    Row(
        modifier = modifier.semantics { contentDescription = if (live) "Heart rate $bpm" else "Heart-rate strap not connected" },
        horizontalArrangement = Arrangement.spacedBy(OrSpacing.xs + OrSpacing.xs / 2),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Favorite, contentDescription = null, tint = color, modifier = Modifier.size(OrSize.IconInline))
        OrLabel(text = if (live) "$bpm" else "HR", style = OrType.Caption, color = if (live) OrColors.OnBackground else OrColors.OnSurfaceMuted)
    }
}
