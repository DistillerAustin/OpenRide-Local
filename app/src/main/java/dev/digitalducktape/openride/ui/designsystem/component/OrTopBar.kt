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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
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
 * with the screen gutter on both sides. Screens don't draw their own headers; they put their
 * actions here with [TopBarActions].
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

/** Where the current screen's top-bar actions are held; the shell provides one ([LocalTopBarActions]). */
class TopBarActionsHolder {
    var content: (@Composable RowScope.() -> Unit)? by mutableStateOf(null)
}

val LocalTopBarActions = staticCompositionLocalOf<TopBarActionsHolder?> { null }

/**
 * Puts [content] (a screen's own buttons: Random ride, Export CSV) in the shared [OrTopBar] for
 * as long as the calling screen is shown. Outside the tabbed shell it draws nothing.
 */
@Composable
fun TopBarActions(content: @Composable RowScope.() -> Unit) {
    val holder = LocalTopBarActions.current ?: return
    val latest by rememberUpdatedState(content)
    DisposableEffect(holder) {
        val mine: @Composable RowScope.() -> Unit = { latest() }
        holder.content = mine
        // The next tab's screen may have taken the slot already; only clear our own.
        onDispose { if (holder.content === mine) holder.content = null }
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
