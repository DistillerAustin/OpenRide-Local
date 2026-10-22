package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * The one way a control's label is drawn (buttons, chips, tabs, the top bar's title and rider
 * chip): always one line and never shortened, so the control grows to fit its text instead
 * (docs/MAIN_UI_REFRESH.md §3, "One line, never cut"). `OrSingleLineLabelTest` renders every
 * control with its longest real label and fails if any of them wraps or overflows.
 */
@Composable
fun OrLabel(
    text: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
) {
    Text(
        text = text,
        style = style,
        color = color,
        maxLines = 1,
        softWrap = false,
        overflow = TextOverflow.Visible,
        modifier = modifier,
    )
}

/** A tracked-caps label above a title or a number. [text] is shown upper-cased. */
@Composable
fun OrEyebrow(text: String, modifier: Modifier = Modifier, color: Color = OrColors.OnSurfaceMuted) {
    OrLabel(text = text.uppercase(), style = OrType.Eyebrow, color = color, modifier = modifier)
}

/** The "BETA" tag shown wherever the mini-games are advertised. */
@Composable
fun OrBetaBadge(modifier: Modifier = Modifier) {
    OrLabel(
        text = "BETA",
        style = OrType.Badge,
        color = OrColors.OnAccent,
        modifier = modifier
            .background(OrColors.Warning, OrShapes.Small)
            .padding(horizontal = OrSpacing.sm + OrSpacing.xs / 2, vertical = OrSpacing.xs),
    )
}

@ComponentPreview
@Composable
private fun OrLabelsPreview() {
    OpenRideTheme {
        Row(
            modifier = Modifier.padding(OrSpacing.lg),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OrEyebrow("Just ride", color = OrColors.Accent)
            OrEyebrow("Welcome back")
            OrBetaBadge()
        }
    }
}
