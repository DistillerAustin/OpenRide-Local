package dev.digitalducktape.openride.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.digitalducktape.openride.core.data.Profile
import dev.digitalducktape.openride.ui.common.ProfileAvatar
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrLabel

/** The active rider at the right of every tab's top bar: their avatar and name; a tap switches rider. */
@Composable
fun RiderChip(profile: Profile?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .heightIn(min = OrSize.Button)
            .clip(OrShapes.Pill)
            .background(OrColors.SurfaceRaised)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = "Switch rider" }
            .padding(start = OrSpacing.xs, end = OrSpacing.md),
        horizontalArrangement = Arrangement.spacedBy(OrSpacing.sm + OrSpacing.xs / 2),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ProfileAvatar(profile = profile, size = 40.dp, emojiSize = 20.sp)
        OrLabel(text = profile?.name ?: "Rider", style = OrType.Button, color = OrColors.OnBackground)
    }
}
