package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * A titled group of [OrSettingsRow]s on one [OrColors.Surface] card, rows separated by hairlines
 * (the caller puts [OrSettingsDivider] between them).
 */
@Composable
fun OrSettingsGroup(title: String, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = modifier) {
        OrEyebrow(text = title, modifier = Modifier.padding(start = OrSpacing.md, bottom = OrSpacing.sm))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(OrShapes.Medium)
                .background(OrColors.Surface),
            content = content,
        )
    }
}

/** The hairline between two rows of an [OrSettingsGroup]. */
@Composable
fun OrSettingsDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = OrSpacing.lg)
            .height(1.dp)
            .background(OrColors.Divider),
    )
}

/**
 * One settings row, at least [OrSize.SettingsRow] tall: a title, an optional [value] under it,
 * and on the right either [trailing] content (buttons) or, for a row that opens something, a
 * chevron. With [onClick] the whole row is one touch target.
 *
 * @param valueColor e.g. [OrColors.Success] for "Paired", [OrColors.Warning] for an error.
 */
@Composable
fun OrSettingsRow(
    title: String,
    modifier: Modifier = Modifier,
    value: String? = null,
    valueColor: Color = OrColors.OnSurfaceMuted,
    onClick: (() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
) {
    val clickable = if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = OrSize.SettingsRow)
            .then(clickable)
            .padding(horizontal = OrSpacing.lg, vertical = OrSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, style = OrType.Subtitle, color = OrColors.OnBackground)
            if (value != null) {
                Text(
                    text = value,
                    style = OrType.Caption,
                    color = valueColor,
                    modifier = Modifier.padding(top = OrSpacing.xs / 2),
                )
            }
        }
        when {
            trailing != null -> Row(
                horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(start = OrSpacing.md),
                content = trailing,
            )
            onClick != null -> Icon(
                imageVector = OrIcons.Chevron,
                contentDescription = null,
                tint = OrColors.OnSurfaceMuted,
                modifier = Modifier.size(OrSize.IconInline + OrSpacing.sm),
            )
        }
    }
}

@ComponentPreview
@Composable
private fun OrSettingsPreview() {
    OpenRideTheme {
        OrSettingsGroup(title = "Ride", modifier = Modifier.width(640.dp).padding(OrSpacing.lg)) {
            OrSettingsRow(title = "Heart-rate strap", value = "Paired", valueColor = OrColors.Success, onClick = {})
            OrSettingsDivider()
            OrSettingsRow(title = "Route (GPX)", value = "Hill loop · 12.40 mi") {
                OrSecondaryButton(text = "Change", onClick = {})
                OrSecondaryButton(text = "Clear", onClick = {})
            }
        }
    }
}
