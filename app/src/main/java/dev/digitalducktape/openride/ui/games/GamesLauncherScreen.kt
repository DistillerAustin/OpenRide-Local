package dev.digitalducktape.openride.ui.games

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.games.GameHostActivity
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrBanner
import dev.digitalducktape.openride.ui.designsystem.component.OrBannerTone
import dev.digitalducktape.openride.ui.designsystem.component.OrBetaBadge
import dev.digitalducktape.openride.ui.designsystem.component.OrPrimaryButton
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * Opens the Games hub (Games hub spec §9): a new visit, or the live one. The hub inside Godot
 * holds everything else: the game picker, circuits and the builder, difficulty, the settings,
 * calibration and the camera permission. The Games tab and the Home card both call this.
 */
fun launchGames(context: Context) {
    context.startActivity(GameHostActivity.intent(context))
}

/**
 * The Games tab (beta): a launcher. The title, the BETA badge, one line, and one big
 * **Enter Games** button (the screen's primary action) that opens the hub. While the last visit's
 * ride is being saved a notice says so (entering still works: the next visit waits for the save).
 */
@Composable
fun GamesLauncherScreen(saving: Boolean, onEnter: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(OrSpacing.xxl),
        verticalArrangement = Arrangement.spacedBy(OrSpacing.lg, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // The title is in the shared top bar; the BETA tag stays with the screen's pitch.
        OrBetaBadge()
        Text(
            "Pick games and circuits inside. Your whole visit is one ride.",
            style = OrType.Body,
            color = OrColors.OnSurfaceMuted,
            textAlign = TextAlign.Center,
        )
        OrPrimaryButton(
            text = "Enter Games",
            onClick = onEnter,
            modifier = Modifier.widthIn(min = 320.dp).padding(top = OrSpacing.md),
        )
        if (saving) {
            OrBanner(
                text = "Saving your last games ride\u2026",
                tone = OrBannerTone.Warning,
                modifier = Modifier.widthIn(max = 720.dp),
            )
        } else {
            Text(
                "Build your own circuits, calibrate once, and play as many games as you like.",
                style = OrType.Body,
                color = OrColors.OnSurfaceMuted,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/** The small "BETA" tag shown wherever the games are advertised. */
@Composable
fun BetaBadge(modifier: Modifier = Modifier) = OrBetaBadge(modifier)

@BikePreview
@Composable
private fun GamesLauncherPreview() {
    OpenRideTheme { GamesLauncherScreen(saving = false, onEnter = {}) }
}

@BikePreview
@Composable
private fun GamesLauncherSavingPreview() {
    OpenRideTheme { GamesLauncherScreen(saving = true, onEnter = {}) }
}
