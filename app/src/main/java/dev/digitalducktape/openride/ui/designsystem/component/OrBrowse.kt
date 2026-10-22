package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/*
 * Browse-screen components (docs/MAIN_UI_REFRESH.md phase 6): what History, Classes, the
 * Creator page and the Ride summary share. Stateless like the rest of the design system, except
 * that a dropdown chip remembers whether its own menu is open.
 */

/**
 * The back arrow on full-screen flows that have no shared top bar (Creator page). Material Icons
 * core; it belongs in `OrIcons` as `Back` (see the phase 6 report) and moves there when it does.
 */
private val BackIcon: ImageVector = Icons.AutoMirrored.Filled.ArrowBack

/**
 * The star in a game's 0–3 rating. `OrIcons` has no `Star` of its own yet; [OrIcons.Games] is
 * Material's filled star, so it is used here. Swap to `OrIcons.Star` once one exists.
 */
private val RatingStar: ImageVector = OrIcons.Games

/**
 * A round, icon-only button at the touch minimum ([OrSize.TouchMin]): month arrows on the
 * calendar. Always give a [contentDescription]; the icon is the only label.
 */
@Composable
fun OrIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = OrColors.OnBackground,
    iconModifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(OrSize.TouchMin)
            .clip(CircleShape)
            .background(OrColors.SurfaceRaised)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = iconModifier.size(OrSize.IconInline + OrSpacing.xs))
    }
}

/**
 * The header of a full-screen browse flow that leaves the tabs (Creator page): a **Back**
 * button, the [title] and optional [actions] on the right, [OrSize.TopBar] tall like the shared
 * top bar so the two read as one family.
 */
@Composable
fun OrScreenHeader(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    backLabel: String = "Back",
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(
        modifier = modifier.fillMaxWidth().heightIn(min = OrSize.TopBar),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OrSecondaryButton(text = backLabel, onClick = onBack, icon = BackIcon)
        OrLabel(
            text = title,
            style = OrType.ScreenTitle,
            color = OrColors.OnBackground,
            modifier = Modifier.padding(start = OrSpacing.lg),
        )
        Spacer(Modifier.weight(1f))
        Row(
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
            content = actions,
        )
    }
}

/**
 * A shelf's title: tracked caps, and with [onClick] a chevron and a whole-row touch target of
 * at least [OrSize.TouchMin] (a creator's name opens their page).
 */
@Composable
fun OrShelfHeader(
    title: String,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    onClickLabel: String? = null,
) {
    val clickable = if (onClick != null) {
        Modifier.clip(OrShapes.Small).clickable(role = Role.Button, onClickLabel = onClickLabel, onClick = onClick)
    } else {
        Modifier
    }
    Row(
        modifier = modifier.heightIn(min = OrSize.TouchMin).then(clickable),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OrEyebrow(text = title, color = if (onClick != null) OrColors.OnBackground else OrColors.OnSurfaceMuted)
        if (onClick != null) {
            Icon(
                imageVector = OrIcons.Chevron,
                contentDescription = null,
                tint = OrColors.OnSurfaceMuted,
                modifier = Modifier.padding(start = OrSpacing.xs).size(OrSize.IconInline),
            )
        }
    }
}

/** One headline number: "TOTAL OUTPUT" / "412" / "KJ". [unit] is optional. */
data class OrStatValue(val label: String, val value: String, val unit: String? = null)

/** A [OrStatValue]: an eyebrow over a big number and its unit. */
@Composable
fun OrStat(
    stat: OrStatValue,
    modifier: Modifier = Modifier,
    labelColor: Color = OrColors.OnSurfaceMuted,
    valueStyle: TextStyle = OrType.StatValue,
) {
    Column(modifier = modifier) {
        OrEyebrow(text = stat.label, color = labelColor)
        Row(verticalAlignment = Alignment.Bottom) {
            OrLabel(text = stat.value, style = valueStyle, color = OrColors.OnBackground)
            if (stat.unit != null) {
                OrLabel(
                    text = stat.unit.uppercase(),
                    style = OrType.Eyebrow,
                    color = OrColors.OnSurfaceMuted,
                    modifier = Modifier.padding(start = OrSpacing.sm, bottom = OrSpacing.sm),
                )
            }
        }
    }
}

/** A row of [OrStat]s, optionally under a [title] eyebrow (History's bands, the summary's band). */
@Composable
fun OrStatBand(
    stats: List<OrStatValue>,
    modifier: Modifier = Modifier,
    title: String? = null,
    labelColor: Color = OrColors.OnSurfaceMuted,
    spacing: Dp = OrSpacing.xl,
) {
    Column(modifier = modifier) {
        if (title != null) {
            OrEyebrow(text = title, color = OrColors.Accent, modifier = Modifier.padding(bottom = OrSpacing.sm))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
            stats.forEach { OrStat(stat = it, labelColor = labelColor) }
        }
    }
}

/**
 * A tappable list row on [OrColors.Surface] (a ride in History): [leading] on the left, filling
 * the width, [trailing] right-aligned. At least [OrSize.SettingsRow] tall.
 */
@Composable
fun OrListRow(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    trailing: @Composable ColumnScope.() -> Unit = {},
    leading: @Composable ColumnScope.() -> Unit,
) {
    val clickable = if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = OrSize.SettingsRow)
            .clip(OrShapes.Small)
            .background(OrColors.Surface)
            .then(clickable)
            .padding(horizontal = OrSpacing.lg, vertical = OrSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), content = leading)
        Column(horizontalAlignment = Alignment.End, content = trailing)
    }
}

/** The design system's spinner, in the rider's accent. */
@Composable
fun OrSpinner(modifier: Modifier = Modifier, size: Dp = OrSize.TouchMin) {
    CircularProgressIndicator(color = OrColors.Accent, trackColor = Color.Transparent, modifier = modifier.size(size))
}

/** A whole area that is still loading: a centred [OrSpinner]. */
@Composable
fun OrLoading(modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) { OrSpinner() }
}

/**
 * An empty or failed area: a centred [message] and, with [actionText], one secondary button
 * under it (Retry).
 */
@Composable
fun OrEmptyState(
    message: String,
    modifier: Modifier = Modifier,
    actionText: String? = null,
    onAction: () -> Unit = {},
) {
    Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(text = message, style = OrType.Subtitle, color = OrColors.OnSurfaceMuted)
            if (actionText != null) {
                OrSecondaryButton(text = actionText, onClick = onAction, modifier = Modifier.padding(top = OrSpacing.md))
            }
        }
    }
}

/**
 * [stars] out of [max] as icons (the tablet's font has no ★/☆ glyphs; rider bike test
 * 2026-10-21): earned ones in the accent, the rest dimmed to [OrColors.Outline].
 */
@Composable
fun OrStarRating(stars: Int, modifier: Modifier = Modifier, max: Int = 3, size: Dp = OrSize.NavIcon) {
    Row(modifier = modifier.semantics { contentDescription = "$stars of $max stars" }) {
        repeat(max) { i ->
            Icon(
                imageVector = RatingStar,
                contentDescription = null,
                tint = if (i < stars) OrColors.Accent else OrColors.Outline,
                modifier = Modifier.size(size),
            )
        }
    }
}

/**
 * A small solid pill laid over a thumbnail or beside a title ("TAKEN JUL 19", "12:34"): text on
 * [OrColors.Surface], an optional [icon] in [iconTint].
 */
@Composable
fun OrOverlayBadge(
    text: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconTint: Color = OrColors.OnBackground,
    style: TextStyle = OrType.Badge,
    textColor: Color = OrColors.OnBackground,
    background: Color = OrColors.Surface,
) {
    Row(
        modifier = modifier
            .background(background, OrShapes.Small)
            .padding(horizontal = OrSpacing.sm, vertical = OrSpacing.xs / 2),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.padding(end = OrSpacing.xs).size(18.dp))
        }
        OrLabel(text = text, style = style, color = textColor)
    }
}

/**
 * An [OrChip] in its dropdown form that opens a menu of [options] (value to label); picking one
 * calls [onSelected]. The menu is drawn on [OrColors.SurfaceRaised] with [OrType.Body] items at
 * least [OrSize.TouchMin] tall.
 */
@Composable
fun <T> OrDropdownChip(
    label: String,
    options: List<Pair<T, String>>,
    onSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
    selectedValue: T? = null,
) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier = modifier) {
        OrChip(text = label, selected = false, onClick = { expanded = true }, dropdown = true)
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            containerColor = OrColors.SurfaceRaised,
            shape = OrShapes.Small,
            tonalElevation = 0.dp,
            shadowElevation = 0.dp,
        ) {
            options.forEach { (value, text) ->
                DropdownMenuItem(
                    text = {
                        OrLabel(
                            text = text,
                            style = OrType.Body,
                            color = if (value == selectedValue) OrColors.Accent else OrColors.OnBackground,
                        )
                    },
                    onClick = {
                        expanded = false
                        onSelected(value)
                    },
                    modifier = Modifier.heightIn(min = OrSize.TouchMin),
                )
            }
        }
    }
}

/**
 * A small form in a dialog (the ride goal): [title], the caller's [content], then Cancel and an
 * accent [confirmText] button. For a yes/no question use [OrConfirmDialog] instead.
 */
@Composable
fun OrFormDialog(
    title: String,
    confirmText: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = modifier
                .widthIn(min = 400.dp, max = 560.dp)
                .clip(OrShapes.Medium)
                .background(OrColors.Surface)
                .padding(OrSpacing.lg),
        ) {
            OrLabel(text = title, style = OrType.Title, color = OrColors.OnBackground)
            Column(modifier = Modifier.padding(vertical = OrSpacing.md), content = content)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(OrSpacing.md, Alignment.End),
            ) {
                OrSecondaryButton(text = "Cancel", onClick = onDismiss)
                OrAccentButton(text = confirmText, onClick = onConfirm)
            }
        }
    }
}

/** One choice of a single-choice group: a radio and its label, the whole row a touch target. */
@Composable
fun OrRadioRow(label: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = OrSize.TouchMin)
            .clip(OrShapes.Small)
            .selectable(selected = selected, onClick = onClick, role = Role.RadioButton),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(
            selected = selected,
            onClick = null,
            colors = RadioButtonDefaults.colors(selectedColor = OrColors.Accent, unselectedColor = OrColors.OnSurfaceMuted),
            modifier = Modifier.padding(horizontal = OrSpacing.sm),
        )
        OrLabel(text = label, style = OrType.Body, color = OrColors.OnBackground)
    }
}

/** A one-line text field on [OrColors.SurfaceRaised], [OrType.Body] text, accent when focused. */
@Composable
fun OrTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(text = label, style = OrType.Caption) },
        singleLine = true,
        textStyle = OrType.Body,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = OrShapes.Small,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = OrColors.OnBackground,
            unfocusedTextColor = OrColors.OnBackground,
            focusedContainerColor = OrColors.SurfaceRaised,
            unfocusedContainerColor = OrColors.SurfaceRaised,
            focusedBorderColor = OrColors.Accent,
            unfocusedBorderColor = OrColors.Outline,
            focusedLabelColor = OrColors.Accent,
            unfocusedLabelColor = OrColors.OnSurfaceMuted,
            cursorColor = OrColors.Accent,
        ),
        modifier = modifier.heightIn(min = OrSize.PrimaryAction),
    )
}

@ComponentPreview
@Composable
private fun OrBrowsePreview() {
    OpenRideTheme {
        Column(
            modifier = Modifier.width(720.dp).padding(OrSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(OrSpacing.md),
        ) {
            OrScreenHeader(title = "Hill Club", onBack = {})
            OrShelfHeader(title = "Hill Club", onClick = {})
            OrStatBand(
                title = "Lifetime",
                stats = listOf(OrStatValue("Total rides", "42"), OrStatValue("Total output", "12840", "kJ")),
            )
            OrListRow(onClick = {}, trailing = {
                Text("412.0 kJ", style = OrType.Subtitle, color = OrColors.OnBackground)
            }) {
                Text("Oct 21, 2026", style = OrType.Subtitle, color = OrColors.OnBackground)
                Text("45:12", style = OrType.Caption, color = OrColors.OnSurfaceMuted)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(OrSpacing.md), verticalAlignment = Alignment.CenterVertically) {
                OrStarRating(stars = 2)
                OrOverlayBadge(text = "TAKEN JUL 19")
                OrDropdownChip(label = "Newest", options = listOf(1 to "Newest"), onSelected = {})
                OrIconButton(icon = OrIcons.Chevron, contentDescription = "Next month", onClick = {})
            }
            OrRadioRow(label = "Time target", selected = true, onClick = {})
            Box(Modifier.height(120.dp)) { OrEmptyState(message = "No classes match these filters") }
        }
    }
}
