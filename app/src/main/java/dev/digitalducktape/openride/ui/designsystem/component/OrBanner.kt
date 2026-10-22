package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/** How loud a banner is. */
enum class OrBannerTone(val stripe: Color) {
    Info(OrColors.Info),
    Warning(OrColors.Warning),
}

/**
 * A full-width, one-line notice on [OrColors.SurfaceRaised] with a coloured edge and icon: the
 * shell's update and sensor notices (`AppNotices`), and later the auto-pause notice. [actions] go on the right
 * (use [OrSecondaryButton] / [OrAccentButton] so they stay at the touch minimum).
 */
@Composable
fun OrBanner(
    text: String,
    modifier: Modifier = Modifier,
    tone: OrBannerTone = OrBannerTone.Info,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .heightIn(min = OrSize.PrimaryAction + OrSpacing.sm)
            .clip(OrShapes.Medium)
            .background(OrColors.SurfaceRaised),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .width(OrSpacing.sm)
                .fillMaxHeight()
                .background(tone.stripe),
        )
        Icon(
            imageVector = if (tone == OrBannerTone.Warning) OrIcons.Warning else OrIcons.Info,
            contentDescription = null,
            tint = tone.stripe,
            modifier = Modifier.padding(start = OrSpacing.lg).size(OrSize.IconInline),
        )
        Text(
            text = text,
            style = OrType.Body,
            color = OrColors.OnBackground,
            maxLines = 1,
            modifier = Modifier.weight(1f).padding(horizontal = OrSpacing.md),
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(vertical = OrSpacing.md).padding(end = OrSpacing.md),
            content = actions,
        )
    }
}

@ComponentPreview
@Composable
private fun OrBannerPreview() {
    OpenRideTheme {
        Column(Modifier.width(960.dp).padding(OrSpacing.lg), verticalArrangement = Arrangement.spacedBy(OrSpacing.md)) {
            OrBanner("OpenRide 0.6.0 is available") {
                OrSecondaryButton("Dismiss", onClick = {})
                OrAccentButton("Update", onClick = {})
            }
            OrBanner("Saving your last games ride…", tone = OrBannerTone.Warning)
        }
    }
}
