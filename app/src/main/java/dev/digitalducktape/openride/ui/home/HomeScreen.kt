package dev.digitalducktape.openride.ui.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.digitalducktape.openride.core.data.Profile
import dev.digitalducktape.openride.core.ride.RideGoal
import dev.digitalducktape.openride.ui.common.ProfileAvatar
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrAccentButton
import dev.digitalducktape.openride.ui.designsystem.component.OrBanner
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
    onOpenProfile: () -> Unit,
    modifier: Modifier = Modifier,
    onOpenGames: () -> Unit = {},
    updateVersionName: String? = null,
    onOpenUpdate: () -> Unit = {},
    onDismissUpdate: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    HomeScreen(
        uiState = uiState,
        onStartRide = { if (viewModel.startQuickRide()) onQuickStart() },
        onSetGoal = viewModel::setGoal,
        onOpenProfile = onOpenProfile,
        onOpenGames = onOpenGames,
        updateVersionName = updateVersionName,
        onOpenUpdate = onOpenUpdate,
        onDismissUpdate = onDismissUpdate,
        modifier = modifier,
    )
}

/**
 * Home tab (PRD P0-7), stateless: the update notice, a greeting with the rider's avatar (tap for
 * the Profile tab), and two tiles side by side. *Just ride* holds the screen's one primary action,
 * an 80 dp **Start ride**, with the pre-ride goal (PRD P1-3) just above it; *Games* (BETA) opens
 * the games hub. The curated classes live in the Classes tab, not here.
 *
 * Laid out for the bike window (1160 × 672 dp beside the rail); it scrolls rather than squeezing
 * if a large font scale or the update notice needs more height.
 */
@Composable
fun HomeScreen(
    uiState: HomeUiState,
    onStartRide: () -> Unit,
    onSetGoal: (RideGoal) -> Unit,
    onOpenProfile: () -> Unit,
    onOpenGames: () -> Unit,
    modifier: Modifier = Modifier,
    updateVersionName: String? = null,
    onOpenUpdate: () -> Unit = {},
    onDismissUpdate: () -> Unit = {},
) {
    var showGoalDialog by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = OrSpacing.ScreenGutter, vertical = OrSpacing.xl),
        verticalArrangement = Arrangement.spacedBy(OrSpacing.lg),
    ) {
        // PRD #22/T22: the launch-time update check surfaces here. Nothing installs without an
        // explicit tap on the App updates screen.
        if (updateVersionName != null) {
            OrBanner(text = "OpenRide $updateVersionName is available") {
                OrSecondaryButton(text = "Dismiss", onClick = onDismissUpdate)
                OrAccentButton(text = "Update", onClick = onOpenUpdate)
            }
        }

        Greeting(uiState = uiState, onOpenProfile = onOpenProfile)

        Row(
            // Both tiles share one height: at least enough to fill the bike window below the
            // greeting (so the Start button sits low, near the rider's hand), more if a large
            // font scale needs it.
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = if (updateVersionName != null) TilesMinHeightWithBanner else TilesMinHeight)
                .height(IntrinsicSize.Min),
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

/**
 * The tiles' minimum height in the 672 dp bike window: what is left after the vertical padding
 * (2 × 32), the greeting (80) and its gap (24) is 504 dp; the update notice and its gap take
 * another 120. A little is left spare so nothing scrolls on the bike.
 */
private val TilesMinHeight = 480.dp
private val TilesMinHeightWithBanner = 360.dp

@Composable
private fun Greeting(uiState: HomeUiState, onOpenProfile: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(modifier = Modifier.weight(1f)) {
            OrEyebrow(text = "Welcome back")
            Text(
                text = uiState.riderName,
                style = OrType.ScreenTitle,
                color = OrColors.OnBackground,
                modifier = Modifier.padding(top = OrSpacing.xs),
            )
        }
        // Tapping the rider's own face is the natural "go to my profile" gesture.
        ProfileAvatar(
            profile = uiState.profile,
            size = OrSize.PrimaryAction,
            emojiSize = 36.sp,
            modifier = Modifier
                .clip(CircleShape)
                .clickable(role = Role.Button, onClick = onOpenProfile)
                .semantics { contentDescription = "Open your profile" },
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
            onOpenProfile = {},
            onOpenGames = {},
        )
    }
}

@BikePreview
@Composable
private fun HomeScreenWithUpdatePreview() {
    OpenRideTheme {
        HomeScreen(
            uiState = HomeUiState(profile = previewRider),
            onStartRide = {},
            onSetGoal = {},
            onOpenProfile = {},
            onOpenGames = {},
            updateVersionName = "0.6.0",
        )
    }
}
