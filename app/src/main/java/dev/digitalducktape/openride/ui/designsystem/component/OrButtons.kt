package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * A screen's one primary action: an [OrSize.PrimaryAction]-tall accent button (Start ride, Enter
 * Games). Use at most one per screen.
 */
@Composable
fun OrPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        shape = OrShapes.Medium,
        colors = ButtonDefaults.buttonColors(
            containerColor = OrColors.Accent,
            contentColor = OrColors.OnAccent,
            disabledContainerColor = OrColors.SurfaceRaised,
            disabledContentColor = OrColors.OnSurfaceMuted,
        ),
        contentPadding = PaddingValues(horizontal = OrSpacing.xl),
        modifier = modifier.heightIn(min = OrSize.PrimaryAction),
    ) {
        ButtonContent(text, icon, OrType.ButtonLarge, OrSize.IconInline)
    }
}

/** A filled accent button at the riding touch minimum, for a tile's own action. */
@Composable
fun OrAccentButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        shape = OrShapes.Small,
        colors = ButtonDefaults.buttonColors(
            containerColor = OrColors.Accent,
            contentColor = OrColors.OnAccent,
            disabledContainerColor = OrColors.SurfaceRaised,
            disabledContentColor = OrColors.OnSurfaceMuted,
        ),
        contentPadding = PaddingValues(horizontal = OrSpacing.lg),
        modifier = modifier.heightIn(min = OrSize.TouchMin),
    ) {
        ButtonContent(text, icon, OrType.Button, OrSize.IconInline)
    }
}

/** An outlined secondary action at the riding touch minimum. */
@Composable
fun OrSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        shape = OrShapes.Small,
        border = BorderStroke(OrSpacing.xs / 2, OrColors.Outline),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = OrColors.OnBackground,
            disabledContentColor = OrColors.OnSurfaceMuted,
        ),
        contentPadding = PaddingValues(horizontal = OrSpacing.lg),
        modifier = modifier.heightIn(min = OrSize.TouchMin),
    ) {
        ButtonContent(text, icon, OrType.Button, OrSize.IconInline)
    }
}

/** A stop or destructive action (End ride, Restore): a red fill with white text. */
@Composable
fun OrDangerButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        shape = OrShapes.Small,
        colors = ButtonDefaults.buttonColors(
            containerColor = OrColors.Danger,
            contentColor = OrColors.OnDanger,
            disabledContainerColor = OrColors.SurfaceRaised,
            disabledContentColor = OrColors.OnSurfaceMuted,
        ),
        contentPadding = PaddingValues(horizontal = OrSpacing.lg),
        modifier = modifier.heightIn(min = OrSize.TouchMin),
    ) {
        ButtonContent(text, null, OrType.Button, OrSize.IconInline)
    }
}

@Composable
private fun ButtonContent(text: String, icon: ImageVector?, style: TextStyle, iconSize: Dp) {
    if (icon != null) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(iconSize))
        Text(text, style = style, modifier = Modifier.padding(start = OrSpacing.sm))
    } else {
        Text(text, style = style)
    }
}

@ComponentPreview
@Composable
private fun OrButtonsPreview() {
    OpenRideTheme {
        Column(Modifier.padding(OrSpacing.lg), verticalArrangement = Arrangement.spacedBy(OrSpacing.md)) {
            OrPrimaryButton("Start ride", onClick = {})
            OrAccentButton("Enter Games", onClick = {})
            OrSecondaryButton("Set goal", onClick = {}, icon = OrIcons.Add)
            OrDangerButton("End ride", onClick = {})
        }
    }
}
