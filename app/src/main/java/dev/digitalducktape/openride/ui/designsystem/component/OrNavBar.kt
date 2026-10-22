package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * The main section's bottom navigation (docs/MAIN_UI_REFRESH.md §3, "Shell"): an
 * [OrSize.BottomBar]-tall row on [OrColors.Surface] with a hairline along its top, the way the
 * stock bike software lays out its tabs. Fill it with [OrNavBarItem]s; they share the width.
 */
@Composable
fun OrNavBar(modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    Column(modifier = modifier.fillMaxWidth()) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(OrColors.Divider))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(OrSize.BottomBar - 1.dp)
                .background(OrColors.Surface)
                .selectableGroup(),
            content = content,
        )
    }
}

/**
 * One destination: its icon (or [emoji]) beside an [OrType.NavLabel] label, on one line. The
 * selected one sits on [OrColors.SurfaceRaised] with an accent bar along its top edge and an
 * accent icon and label.
 */
@Composable
fun RowScope.OrNavBarItem(
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
            .weight(1f)
            .fillMaxHeight()
            .background(if (selected) OrColors.SurfaceRaised else Color.Transparent)
            .selectable(selected = selected, onClick = onClick, role = Role.Tab),
    ) {
        if (selected) {
            Box(
                Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .height(OrSpacing.xs)
                    .background(OrColors.Accent),
            )
        }
        Row(
            modifier = Modifier.align(Alignment.Center),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.sm + OrSpacing.xs / 2),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (emoji != null) {
                // The emoji's own colours carry it; an unselected one is simply dimmed.
                Text(text = emoji, fontSize = 24.sp, color = Color.White.copy(alpha = if (selected) 1f else 0.7f))
            } else {
                Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(OrSize.NavIcon))
            }
            OrLabel(text = label, style = OrType.NavLabel, color = tint)
        }
    }
}

@BikePreview
@Composable
private fun OrNavBarPreview() {
    OpenRideTheme {
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.Bottom) {
            OrNavBar {
                OrNavBarItem("Home", OrIcons.Home, selected = true, onClick = {})
                OrNavBarItem("Classes", OrIcons.Classes, selected = false, onClick = {})
                OrNavBarItem("Games", OrIcons.Games, selected = false, onClick = {}, emoji = "🎮")
                OrNavBarItem("History", OrIcons.History, selected = false, onClick = {})
                OrNavBarItem("Profile", OrIcons.Profile, selected = false, onClick = {})
            }
        }
    }
}
