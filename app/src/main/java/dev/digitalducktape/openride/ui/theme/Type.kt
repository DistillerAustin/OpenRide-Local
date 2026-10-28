package dev.digitalducktape.openride.ui.theme

import androidx.compose.material3.Typography
import dev.digitalducktape.openride.ui.designsystem.OrType

/**
 * Material's type scale on the bike scale ([OrType], docs/MAIN_UI_REFRESH.md §5). Screens pass
 * [OrType] styles themselves; this only reaches text Material draws with its own defaults (a
 * `Text` with no style, a menu item, a dialog slot), so that text keeps the same size floors.
 * The display styles stay Material's: they are already 36 sp and up.
 */
val OpenRideTypography = Typography(
    headlineLarge = OrType.ScreenTitle,
    headlineMedium = OrType.ScreenTitle,
    headlineSmall = OrType.Title,
    titleLarge = OrType.Title,
    titleMedium = OrType.Subtitle,
    titleSmall = OrType.Subtitle,
    bodyLarge = OrType.Body,
    bodyMedium = OrType.Body,
    bodySmall = OrType.Caption,
    labelLarge = OrType.Button,
    labelMedium = OrType.Caption,
    labelSmall = OrType.Badge,
)
