package dev.digitalducktape.openride.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrLabel

/**
 * A pill marking a mini-games ride (#35), e.g. "Demo · 20 min", in History and the summary: the
 * rider's accent on [OrColors.SurfaceRaised], one line.
 */
@Composable
fun GameBadge(text: String, modifier: Modifier = Modifier) {
    OrLabel(
        text = "🎮 $text",
        style = OrType.Caption,
        color = OrColors.Accent,
        modifier = modifier
            .background(color = OrColors.SurfaceRaised, shape = OrShapes.Small)
            .padding(horizontal = OrSpacing.sm + OrSpacing.xs, vertical = OrSpacing.xs / 2),
    )
}
