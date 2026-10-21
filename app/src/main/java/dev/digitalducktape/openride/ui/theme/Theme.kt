package dev.digitalducktape.openride.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import dev.digitalducktape.openride.ui.designsystem.OrColors

/**
 * App-wide dark theme on the design-system tokens ([OrColors], docs/MAIN_UI_REFRESH.md §3).
 * There is deliberately no light variant and no dynamic colour: the bike always runs this theme,
 * and Android 11 has no dynamic colour anyway.
 *
 * Material components that read the scheme (dialogs, text fields, chips, menus) get the same
 * surfaces as the design system, so screens not yet rebuilt still match the new look.
 */
private val OpenRideColorScheme = darkColorScheme(
    background = OrColors.Background,
    onBackground = OrColors.OnBackground,
    surface = OrColors.Surface,
    onSurface = OrColors.OnBackground,
    surfaceVariant = OrColors.SurfaceRaised,
    onSurfaceVariant = OrColors.OnSurfaceMuted,
    surfaceContainerLowest = OrColors.Background,
    surfaceContainerLow = OrColors.Surface,
    surfaceContainer = OrColors.Surface,
    surfaceContainerHigh = OrColors.SurfaceRaised,
    surfaceContainerHighest = OrColors.SurfaceRaised,
    surfaceBright = OrColors.SurfaceRaised,
    surfaceDim = OrColors.Background,
    inverseSurface = OrColors.OnBackground,
    inverseOnSurface = OrColors.Background,
    primary = OrColors.Accent,
    onPrimary = OrColors.OnAccent,
    primaryContainer = OrColors.SurfaceRaised,
    onPrimaryContainer = OrColors.OnBackground,
    inversePrimary = OrColors.OnAccent,
    secondary = OrColors.Info,
    onSecondary = OrColors.OnAccent,
    secondaryContainer = OrColors.SurfaceRaised,
    onSecondaryContainer = OrColors.OnBackground,
    tertiary = OrColors.Warning,
    onTertiary = OrColors.OnAccent,
    // Error *text* sits on dark surfaces, so it stays amber (red text fails contrast there);
    // the red Danger token is for fills only.
    error = OrColors.Warning,
    onError = OrColors.OnAccent,
    errorContainer = OrColors.Danger,
    onErrorContainer = OrColors.OnDanger,
    outline = OrColors.Outline,
    outlineVariant = OrColors.Divider,
    scrim = OrColors.Scrim,
)

@Composable
fun OpenRideTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = OpenRideColorScheme,
        typography = OpenRideTypography,
        content = content,
    )
}
