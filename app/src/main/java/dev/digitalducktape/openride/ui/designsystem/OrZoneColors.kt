package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.graphics.Color
import dev.digitalducktape.openride.core.ride.PowerZone

/**
 * The power-zone ramp, cool to hot, one colour per [PowerZone] (zones 1 to 7). A standard
 * training-zone colour language (recovery grey-blue through threshold red), not any vendor's
 * palette, and kept as it was when the rest of the app moved to "Night Road".
 *
 * Zone colours are only drawn as large numerals (the output reading) or as a small swatch beside
 * text, never as body text: zones 1, 2 and 7 sit under 4.5 : 1 on the dark ground. The large-text
 * pairs are in [OrColorPairs].
 */
val OrZoneColors: List<Color> = listOf(
    Color(0xFF6E7B8B),
    Color(0xFF3D7BD9),
    Color(0xFF2FA8A0),
    Color(0xFF35C46A),
    Color(0xFFF2B22B),
    Color(0xFFEF7D2E),
    Color(0xFFE8442D),
)

/** [zone]'s colour, or muted text when there is no zone (no FTP set). */
fun zoneColor(zone: PowerZone?): Color =
    zone?.number?.let { OrZoneColors.getOrNull(it - 1) } ?: OrColors.OnSurfaceMuted
