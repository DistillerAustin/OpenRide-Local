package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * A flat card on [OrColors.Surface]: the building block of Home and the settings groups. No
 * shadow (§0 rule 4: tonal surfaces only). With [onClick] the whole tile is one touch target.
 */
@Composable
fun OrTile(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    contentPadding: PaddingValues = PaddingValues(OrSpacing.xl),
    content: @Composable ColumnScope.() -> Unit,
) {
    val clickable = if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier
    Column(
        modifier = modifier
            .clip(OrShapes.Large)
            .background(OrColors.Surface)
            .then(clickable)
            .padding(contentPadding),
        content = content,
    )
}

@ComponentPreview
@Composable
private fun OrTilePreview() {
    OpenRideTheme {
        OrTile(modifier = Modifier.width(480.dp).padding(OrSpacing.lg)) {
            OrEyebrow("Just ride", color = OrColors.Accent)
            Text("Quick start", style = OrType.Title, color = OrColors.OnBackground)
            Text("Free ride with live cadence, resistance and output", style = OrType.Body, color = OrColors.OnSurfaceMuted)
        }
    }
}
