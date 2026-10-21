package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * The one top bar every tab shares (docs/MAIN_UI_REFRESH.md §3, "Shell"): [title] at the left,
 * then the current screen's [actions], then [trailing] (the rider chip), all [OrSize.TopBar] tall
 * with the screen gutter on both sides. Screens don't draw their own headers; the shell passes
 * each tab's actions in, so the bar and the tab are drawn in the same frame.
 */
@Composable
fun OrTopBar(
    title: String,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {},
    trailing: @Composable () -> Unit = {},
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(OrSize.TopBar)
            .padding(horizontal = OrSpacing.ScreenGutter),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OrLabel(text = title, style = OrType.ScreenTitle, color = OrColors.OnBackground)
        Spacer(Modifier.weight(1f))
        Row(
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
            content = actions,
        )
        Spacer(Modifier.width(OrSpacing.lg))
        trailing()
    }
}

@BikePreview
@Composable
private fun OrTopBarPreview() {
    OpenRideTheme {
        OrTopBar(
            title = "Classes",
            actions = { OrAccentButton(text = "Random ride", onClick = {}) },
            trailing = { OrSecondaryButton(text = "Ed", onClick = {}) },
        )
    }
}
