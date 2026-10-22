package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/*
 * Form controls for the settings flows (profile editor, content sources, HR pairing, updates):
 * a text field, a switch, a picker swatch and a busy spinner, all in the design system's colours
 * and sizes. Material's own controls underneath, re-coloured; nothing here draws a shadow.
 */

/**
 * A one-line text input on [OrColors.SurfaceRaised] with an [OrType.Body] value and a floating
 * [label]. [error] shows under the field in [OrColors.Warning] (red text fails contrast on the
 * dark ground, docs/MAIN_UI_REFRESH.md §5); the line under the field is always reserved, so a
 * message appearing never moves what's below it.
 *
 * Meant to sit on [OrColors.Surface] (an [OrTile]) or [OrColors.Background]: the floating label
 * and the error line are drawn on whatever is behind the field.
 */
@Composable
fun OrTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    error: String? = null,
    enabled: Boolean = true,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        enabled = enabled,
        singleLine = true,
        textStyle = OrType.Body,
        shape = OrShapes.Small,
        label = label?.let { { Text(text = it, style = OrType.Caption) } },
        placeholder = placeholder?.let { { Text(text = it, style = OrType.Body) } },
        isError = error != null,
        supportingText = { Text(text = error ?: "", style = OrType.Caption) },
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        colors = orTextFieldColors(),
    )
}

@Composable
private fun orTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = OrColors.OnBackground,
    unfocusedTextColor = OrColors.OnBackground,
    disabledTextColor = OrColors.OnSurfaceMuted,
    errorTextColor = OrColors.OnBackground,
    focusedContainerColor = OrColors.SurfaceRaised,
    unfocusedContainerColor = OrColors.SurfaceRaised,
    disabledContainerColor = OrColors.SurfaceRaised,
    errorContainerColor = OrColors.SurfaceRaised,
    cursorColor = OrColors.Accent,
    errorCursorColor = OrColors.Warning,
    // 30 %: OnBackground text over the highlight stays above 4.5 : 1 (about 5.8 : 1 on lime);
    // 40 % dropped to 4.4.
    selectionColors = TextSelectionColors(handleColor = OrColors.Accent, backgroundColor = OrColors.Accent.copy(alpha = 0.3f)),
    focusedBorderColor = OrColors.Accent,
    unfocusedBorderColor = OrColors.Outline,
    disabledBorderColor = OrColors.Outline,
    errorBorderColor = OrColors.Warning,
    focusedLabelColor = OrColors.Accent,
    unfocusedLabelColor = OrColors.OnSurfaceMuted,
    disabledLabelColor = OrColors.OnSurfaceMuted,
    errorLabelColor = OrColors.Warning,
    focusedPlaceholderColor = OrColors.OnSurfaceMuted,
    unfocusedPlaceholderColor = OrColors.OnSurfaceMuted,
    focusedSupportingTextColor = OrColors.OnSurfaceMuted,
    unfocusedSupportingTextColor = OrColors.OnSurfaceMuted,
    errorSupportingTextColor = OrColors.Warning,
)

/**
 * An on/off switch in the rider's accent (Material's own is already [OrSize.TouchMin] or more
 * once its touch padding is counted). [contentDescription] names what it switches, since the row
 * title next to it is a separate node.
 */
@Composable
fun OrSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    contentDescription: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        enabled = enabled,
        modifier = modifier.semantics { this.contentDescription = contentDescription },
        colors = SwitchDefaults.colors(
            checkedThumbColor = OrColors.OnAccent,
            checkedTrackColor = OrColors.Accent,
            checkedBorderColor = Color.Transparent,
            uncheckedThumbColor = OrColors.OnSurfaceMuted,
            uncheckedTrackColor = OrColors.SurfaceRaised,
            uncheckedBorderColor = OrColors.Outline,
        ),
    )
}

/**
 * One choice in a picker of round swatches (avatar colour, avatar icon): [OrSize.TouchMin] across,
 * filled with [color], with an [OrColors.OnBackground] ring inside the circle when [selected] so
 * selection never changes the swatch's footprint. `requiredSize` keeps it round under a tight
 * parent, and the ripple is clipped to the circle.
 */
@Composable
fun OrSwatch(
    selected: Boolean,
    color: Color,
    onClick: () -> Unit,
    contentDescription: String,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit = {},
) {
    val ring = if (selected) Modifier.border(width = 3.dp, color = OrColors.OnBackground, shape = CircleShape) else Modifier
    Box(
        modifier = modifier
            .requiredSize(OrSize.TouchMin)
            .clip(CircleShape)
            .background(color)
            .then(ring)
            .selectable(selected = selected, onClick = onClick, role = Role.RadioButton)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

/**
 * Shown only while a bounded piece of work is in flight (a lookup, a scan, a download) and
 * removed when it ends, so it is never an idle animation (§0 rule 4).
 */
@Composable
fun OrSpinner(modifier: Modifier = Modifier, size: Dp = OrSize.IconInline + OrSpacing.sm) {
    CircularProgressIndicator(
        color = OrColors.Accent,
        trackColor = Color.Transparent,
        strokeWidth = OrSpacing.xs,
        modifier = modifier.size(size),
    )
}

@ComponentPreview
@Composable
private fun OrFormPreview() {
    OpenRideTheme {
        Column(
            modifier = Modifier.width(560.dp).background(OrColors.Surface).padding(OrSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(OrSpacing.md),
        ) {
            OrTextField(value = "Sam", onValueChange = {}, label = "Name")
            OrTextField(value = "", onValueChange = {}, label = "FTP (watts), optional", error = "Enter an FTP in watts greater than 0")
            Row(horizontalArrangement = Arrangement.spacedBy(OrSpacing.md), verticalAlignment = Alignment.CenterVertically) {
                OrSwitch(checked = true, onCheckedChange = {}, contentDescription = "Shown")
                OrSwitch(checked = false, onCheckedChange = {}, contentDescription = "Hidden")
                OrSwatch(selected = true, color = Color(0xFF2D9CE8), onClick = {}, contentDescription = "Blue")
                OrSwatch(selected = false, color = OrColors.SurfaceRaised, onClick = {}, contentDescription = "Bike") {
                    Text("🚴", style = OrType.Body)
                }
                OrSpinner()
            }
        }
    }
}
