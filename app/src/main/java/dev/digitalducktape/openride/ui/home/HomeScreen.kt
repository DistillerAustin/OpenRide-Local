package dev.digitalducktape.openride.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.digitalducktape.openride.core.data.Profile
import dev.digitalducktape.openride.core.ride.RideGoal
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrAccentButton
import dev.digitalducktape.openride.ui.designsystem.component.OrBetaBadge
import dev.digitalducktape.openride.ui.designsystem.component.OrEyebrow
import dev.digitalducktape.openride.ui.designsystem.component.OrPrimaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSecondaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrTile
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * Home tab, connected to its [HomeViewModel] (the Route half of docs/MAIN_UI_REFRESH.md §2's
 * Route/Screen split). Starting a ride only navigates when the view model actually started one,
 * i.e. when a rider is active.
 */
@Composable
fun HomeRoute(
    viewModel: HomeViewModel,
    onQuickStart: () -> Unit,
    modifier: Modifier = Modifier,
    onOpenGames: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    HomeScreen(
        uiState = uiState,
        onStartRide = { if (viewModel.startQuickRide()) onQuickStart() },
        onSetGoal = viewModel::setGoal,
        onOpenGames = onOpenGames,
        modifier = modifier,
    )
}

/**
 * Home tab (PRD P0-7), stateless: the update notice and two tiles side by side, under the shared
 * top bar (which carries the rider). *Just ride* holds the screen's one primary action, **Start
 * ride**, with the pre-ride goal (PRD P1-3) just above it; *Games* (BETA) opens the games hub.
 * The curated classes live in the Classes tab, not here.
 *
 * Laid out for the 1280 × 528 dp between the top and bottom bars; the tiles take whatever height
 * is left, so the shell's notices (update, sensors offline) fit above without scrolling.
 */
@Composable
fun HomeScreen(
    uiState: HomeUiState,
    onStartRide: () -> Unit,
    onSetGoal: (RideGoal) -> Unit,
    onOpenGames: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var showGoalDialog by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, top = OrSpacing.sm, bottom = OrSpacing.lg),
        verticalArrangement = Arrangement.spacedBy(OrSpacing.lg),
    ) {
        Row(
            // Both tiles share whatever height the shell leaves (less when a notice shows above),
            // so Start sits low, near the rider's hand, and nothing ever scrolls.
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.lg),
        ) {
            JustRideTile(
                uiState = uiState,
                onStartRide = onStartRide,
                onEditGoal = { showGoalDialog = true },
                modifier = Modifier.weight(3f).fillMaxHeight(),
            )
            GamesTile(
                onOpenGames = onOpenGames,
                modifier = Modifier.weight(2f).fillMaxHeight(),
            )
        }
    }

    if (showGoalDialog) {
        GoalDialog(
            currentGoal = uiState.goal,
            onDismiss = { showGoalDialog = false },
            onSave = { newGoal ->
                onSetGoal(newGoal)
                showGoalDialog = false
            },
        )
    }
}

@Composable
private fun JustRideTile(
    uiState: HomeUiState,
    onStartRide: () -> Unit,
    onEditGoal: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OrTile(modifier = modifier) {
        OrEyebrow(text = "Just ride", color = OrColors.Accent)
        Text(
            text = "Quick start",
            style = OrType.Title,
            color = OrColors.OnBackground,
            modifier = Modifier.padding(top = OrSpacing.sm),
        )
        Text(
            text = "Free ride with live cadence, resistance and output",
            style = OrType.Body,
            color = OrColors.OnSurfaceMuted,
            modifier = Modifier.padding(top = OrSpacing.xs),
        )
        Spacer(modifier = Modifier.weight(1f).heightIn(min = OrSpacing.lg))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = uiState.goalLabel,
                style = OrType.Subtitle,
                color = if (uiState.goal == RideGoal.None) OrColors.OnSurfaceMuted else OrColors.OnBackground,
                modifier = Modifier.weight(1f),
            )
            OrSecondaryButton(text = uiState.goalActionLabel, onClick = onEditGoal)
        }
        OrPrimaryButton(
            text = "Start ride",
            onClick = onStartRide,
            modifier = Modifier.fillMaxWidth().padding(top = OrSpacing.md),
        )
    }
}

@Composable
private fun GamesTile(onOpenGames: () -> Unit, modifier: Modifier = Modifier) {
    OrTile(modifier = modifier, onClick = onOpenGames) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            OrEyebrow(text = "🎮  Games", color = OrColors.Accent)
            OrBetaBadge(modifier = Modifier.padding(start = OrSpacing.md))
        }
        Text(
            text = "Play your workout",
            style = OrType.Title,
            color = OrColors.OnBackground,
            modifier = Modifier.padding(top = OrSpacing.sm),
        )
        Text(
            text = "Games, circuits and your own builds, in one ride. New, and still being tuned.",
            style = OrType.Body,
            color = OrColors.OnSurfaceMuted,
            modifier = Modifier.padding(top = OrSpacing.xs),
        )
        Spacer(modifier = Modifier.weight(1f).heightIn(min = OrSpacing.lg))
        OrSecondaryButton(
            text = "Enter Games",
            onClick = onOpenGames,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

private val previewRider = Profile(
    id = 1,
    name = "Sam",
    avatarEmoji = "🚴",
    avatarColor = 0xFF3D7BD9.toInt(),
    weightKg = null,
    ftp = 210,
)

@BikePreview
@Composable
private fun HomeScreenPreview() {
    OpenRideTheme {
        HomeScreen(
            uiState = HomeUiState(profile = previewRider, goal = RideGoal.Duration(30 * 60)),
            onStartRide = {},
            onSetGoal = {},
            onOpenGames = {},
        )
    }
}
