package dev.digitalducktape.openride.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Color
import dev.digitalducktape.openride.core.ride.PowerZone
import dev.digitalducktape.openride.ui.designsystem.OrColors

/**
 * The colour names the screens used before the design system existed. They now point at the
 * design-system tokens in [OrColors] ("Night Road", docs/MAIN_UI_REFRESH.md §3), so the whole
 * app re-skins at once; migrated code uses [OrColors] directly, and this object goes away once
 * no screen refers to it.
 */
object OpenRideColors {
    val Background = OrColors.Background
    val Surface = OrColors.Surface
    val SurfaceVariant = OrColors.SurfaceRaised
    val Accent: Color
        @Composable @ReadOnlyComposable
        get() = OrColors.Accent
    val OnAccent = OrColors.OnAccent
    val OnBackground = OrColors.OnBackground
    val OnSurfaceVariant = OrColors.OnSurfaceMuted
    val Warning = OrColors.Warning
    val Success = OrColors.Success
    val Danger = OrColors.Danger
    val OnDanger = OrColors.OnDanger

    /** Translucent black behind text/metrics overlaid on video (v2 Video Ride spec). */
    val ScrimOverlay = OrColors.Scrim

    /** Hairline separators: nav bar top edge, metric-cell dividers. */
    val Divider = OrColors.Divider
}

/**
 * Power-zone accent ramp (v2 redesign spec): cool-to-hot, one color per [PowerZone],
 * used for the in-ride zone chip and the central output block's accent. Standard
 * training-zone color language (recovery grey-blue through threshold red), not any
 * vendor's palette.
 */
fun zoneColor(zone: PowerZone?): Color = when (zone?.number) {
    1 -> Color(0xFF6E7B8B)
    2 -> Color(0xFF3D7BD9)
    3 -> Color(0xFF2FA8A0)
    4 -> Color(0xFF35C46A)
    5 -> Color(0xFFF2B22B)
    6 -> Color(0xFFEF7D2E)
    7 -> Color(0xFFE8442D)
    else -> OpenRideColors.OnSurfaceVariant
}
