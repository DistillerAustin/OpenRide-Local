package dev.digitalducktape.openride.ui.designsystem.component

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType

/**
 * A filter chip ([OrSize.TouchMin] tall, sized to its one-line label): accent with dark text when
 * [selected], raised surface otherwise. With [dropdown] it shows a caret and opens a menu instead
 * of toggling (Newest ▾, Any length ▾).
 */
@Composable
fun OrChip(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    dropdown: Boolean = false,
) {
    val content = if (selected) OrColors.OnAccent else OrColors.OnBackground
    Row(
        modifier = modifier
            .heightIn(min = OrSize.TouchMin)
            .clip(OrShapes.Small)
            .background(if (selected) OrColors.Accent else OrColors.SurfaceRaised)
            .border(1.dp, if (selected) Color.Transparent else OrColors.Outline, OrShapes.Small)
            .selectable(selected = selected, onClick = onClick, role = if (dropdown) Role.DropdownList else Role.Checkbox)
            .padding(start = OrSpacing.md, end = if (dropdown) OrSpacing.sm else OrSpacing.md),
        horizontalArrangement = Arrangement.spacedBy(OrSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OrLabel(text = text, style = OrType.Button, color = content)
        if (dropdown) {
            Icon(Icons.Filled.ArrowDropDown, contentDescription = null, tint = content, modifier = Modifier.size(OrSize.IconInline))
        }
    }
}
