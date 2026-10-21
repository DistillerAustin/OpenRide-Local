package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * The main section's left navigation rail (docs/MAIN_UI_REFRESH.md §3, "Shell"): an
 * [OrSize.RailWidth]-wide column on [OrColors.Surface] with a hairline on its right edge. In
 * landscape the window's height (672 dp) is the scarce axis, so the tabs go down the side rather
 * than along the bottom. Fill it with [OrNavRailItem]s.
 */
@Composable
fun OrNavRail(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Row(modifier = modifier.fillMaxHeight()) {
        Column(
            modifier = Modifier
                .width(OrSize.RailWidth - 1.dp)
                .fillMaxHeight()
                .background(OrColors.Surface)
                .padding(horizontal = OrSpacing.sm)
                .selectableGroup(),
            verticalArrangement = Arrangement.spacedBy(OrSpacing.xs, Alignment.CenterVertically),
            content = content,
        )
        Box(
            modifier = Modifier
                .width(1.dp)
                .fillMaxHeight()
                .background(OrColors.Divider),
        )
    }
}

/**
 * One rail destination: an icon (or an emoji, when [emoji] is set) over an [OrType.NavLabel]
 * label, [OrSize.RailItemHeight] tall. The selected item sits on [OrColors.SurfaceRaised] with an
 * accent bar on its leading edge and accent icon and label.
 */
@Composable
fun OrNavRailItem(
    label: String,
    icon: ImageVector,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    emoji: String? = null,
) {
    val tint = if (selected) OrColors.Accent else OrColors.OnSurfaceMuted
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(OrSize.RailItemHeight)
            .clip(OrShapes.Small)
            .background(if (selected) OrColors.SurfaceRaised else Color.Transparent)
            .selectable(selected = selected, onClick = onClick, role = Role.Tab),
    ) {
        if (selected) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .width(OrSpacing.xs)
                    .height(OrSize.RailItemHeight / 2)
                    .background(OrColors.Accent, OrShapes.Pill),
            )
        }
        Column(
            modifier = Modifier.align(Alignment.Center),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (emoji != null) {
                // The emoji's own colours carry it; an unselected one is simply dimmed.
                Text(
                    text = emoji,
                    fontSize = 30.sp,
                    color = Color.White.copy(alpha = if (selected) 1f else 0.7f),
                )
            } else {
                Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(OrSize.RailIcon))
            }
            Text(
                text = label,
                style = OrType.NavLabel,
                color = if (selected) OrColors.Accent else OrColors.OnSurfaceMuted,
                textAlign = TextAlign.Center,
                maxLines = 1,
                modifier = Modifier.padding(top = OrSpacing.xs),
            )
        }
    }
}

@BikePreview
@Composable
private fun OrNavRailPreview() {
    OpenRideTheme {
        OrNavRail {
            OrNavRailItem("Home", OrIcons.Home, selected = true, onClick = {})
            OrNavRailItem("Classes", OrIcons.Classes, selected = false, onClick = {})
            OrNavRailItem("Games", OrIcons.Games, selected = false, onClick = {}, emoji = "🎮")
            OrNavRailItem("History", OrIcons.History, selected = false, onClick = {})
            OrNavRailItem("Profile", OrIcons.Profile, selected = false, onClick = {})
        }
    }
}
