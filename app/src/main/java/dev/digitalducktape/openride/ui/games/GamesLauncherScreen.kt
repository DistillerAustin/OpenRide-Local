package dev.digitalducktape.openride.ui.games

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.digitalducktape.openride.games.GameHostActivity
import dev.digitalducktape.openride.ui.theme.OpenRideColors

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
 * **Enter Games** button that opens the hub. While the last visit's ride is being saved it
 * says so (entering still works: the next visit waits for the save).
 */
@Composable
fun GamesLauncherScreen(saving: Boolean, onEnter: () -> Unit, modifier: Modifier = Modifier) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier.fillMaxSize().padding(48.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Text("🎮 GAMES", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                BetaBadge()
            }
            Text(
                "Pick games and circuits inside. Your whole visit is one ride.",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Button(
                onClick = onEnter,
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier.widthIn(min = 420.dp).height(112.dp),
            ) {
                Text("Enter Games", fontSize = 34.sp, fontWeight = FontWeight.Bold)
            }
            Text(
                if (saving) "Saving your last games ride…" else "Build your own circuits, calibrate once, and play as many games as you like.",
                style = MaterialTheme.typography.bodyLarge,
                color = if (saving) OpenRideColors.Warning else MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/** The small "BETA" tag shown wherever the games are advertised. */
@Composable
fun BetaBadge(modifier: Modifier = Modifier) {
    Text(
        "BETA",
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.Bold,
        color = OpenRideColors.Background,
        modifier = modifier.background(OpenRideColors.Warning, RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 4.dp),
    )
}
