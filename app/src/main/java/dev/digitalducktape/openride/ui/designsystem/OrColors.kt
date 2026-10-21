package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.Composable

/**
 * OpenRide's colour tokens, "Night Road" (docs/MAIN_UI_REFRESH.md §3): a blue-black ground and a
 * lime signal accent. Original to OpenRide: it deliberately avoids the red-on-black look of the
 * bike's stock software, and no other brand's palette is used as trade dress.
 *
 * Every text/background pair the app uses is listed in [OrColorPairs] and checked for WCAG AA
 * contrast by `OrColorsTest`. Add a pair there when a new combination appears.
 */
object OrColors {
    /** The screen. */
    val Background = Color(0xFF0F1216)

    /** Cards, tiles, the navigation rail. */
    val Surface = Color(0xFF181C22)

    /** The selected rail item, chips, inputs, dialogs: one step up from [Surface]. */
    val SurfaceRaised = Color(0xFF222831)

    /** Hairlines and the secondary button's border. */
    val Outline = Color(0xFF343C48)

    /** Primary text. */
    val OnBackground = Color(0xFFF2F5F8)

    /** Secondary text: captions, labels, units. */
    val OnSurfaceMuted = Color(0xFFA7B0BC)

    /**
     * Primary actions and the selected state: the active rider's own colour (their avatar
     * colour through [riderAccent], provided by `OpenRideTheme`), or [DefaultAccent] before a
     * rider is chosen. Always paired with [OnAccent] text.
     */
    val Accent: Color
        @Composable @ReadOnlyComposable
        get() = LocalOrAccent.current

    /** The accent with no rider: the "Night Road" lime. */
    val DefaultAccent = Color(0xFFC6F24E)

    /** Text and icons on [Accent] (whichever rider's), [Info], [Warning] and [Success] fills. */
    val OnAccent = Color(0xFF0F1216)

    /** Informational banners, links. */
    val Info = Color(0xFF6CC6FF)

    /** BETA badge, auto-pause, "saving", soft errors in text. */
    val Warning = Color(0xFFFFB648)

    /** Stop and destructive actions (End ride, Restore). A fill only, with [OnDanger] text. */
    val Danger = Color(0xFFCC3A2D)

    /** Text on [Danger]. */
    val OnDanger = Color(0xFFFFFFFF)

    /** Done, paired, above average. */
    val Success = Color(0xFF4CD68E)

    /** Translucent black behind text and metrics laid over video. */
    val Scrim = Color(0xB3000000)

    /** Hairline separators on [Background] and [Surface]. */
    val Divider = Color(0x33FFFFFF)
}

/** A foreground drawn on a background, and the contrast it needs. */
data class OrColorPair(val name: String, val foreground: Color, val background: Color, val minContrast: Double)

/** WCAG AA: 4.5 : 1 for body text, 3 : 1 for large text (≥ 24 sp, or 18.5 sp bold) and UI parts. */
internal const val TEXT = 4.5
private const val LARGE = 3.0

/** Every foreground/background combination the design system draws. */
val OrColorPairs: List<OrColorPair> = listOf(
    OrColorPair("text on background", OrColors.OnBackground, OrColors.Background, TEXT),
    OrColorPair("text on surface", OrColors.OnBackground, OrColors.Surface, TEXT),
    OrColorPair("text on raised surface", OrColors.OnBackground, OrColors.SurfaceRaised, TEXT),
    OrColorPair("muted text on background", OrColors.OnSurfaceMuted, OrColors.Background, TEXT),
    OrColorPair("muted text on surface", OrColors.OnSurfaceMuted, OrColors.Surface, TEXT),
    OrColorPair("muted text on raised surface", OrColors.OnSurfaceMuted, OrColors.SurfaceRaised, TEXT),
    OrColorPair("accent text on background", OrColors.DefaultAccent, OrColors.Background, TEXT),
    OrColorPair("accent text on surface", OrColors.DefaultAccent, OrColors.Surface, TEXT),
    OrColorPair("accent text on raised surface", OrColors.DefaultAccent, OrColors.SurfaceRaised, TEXT),
    OrColorPair("text on accent", OrColors.OnAccent, OrColors.DefaultAccent, TEXT),
    OrColorPair("info text on surface", OrColors.Info, OrColors.Surface, TEXT),
    OrColorPair("text on info", OrColors.OnAccent, OrColors.Info, TEXT),
    OrColorPair("warning text on background", OrColors.Warning, OrColors.Background, TEXT),
    OrColorPair("warning text on surface", OrColors.Warning, OrColors.Surface, TEXT),
    OrColorPair("text on warning", OrColors.OnAccent, OrColors.Warning, TEXT),
    OrColorPair("text on danger", OrColors.OnDanger, OrColors.Danger, TEXT),
    OrColorPair("success text on surface", OrColors.Success, OrColors.Surface, TEXT),
    OrColorPair("text on success", OrColors.OnAccent, OrColors.Success, TEXT),
    OrColorPair("secondary button border on background", OrColors.Outline, OrColors.Background, 1.5),
    OrColorPair("danger fill on background", OrColors.Danger, OrColors.Background, LARGE),
)

/** The accent in force: `OpenRideTheme` provides the active rider's ([riderAccent]). */
val LocalOrAccent = staticCompositionLocalOf { OrColors.DefaultAccent }

/**
 * A rider's UI colour from their avatar colour (rider's ask, 2026-10-21: one colour per rider).
 * Lightened toward white just enough that [OrColors.OnAccent] text on it and it as text on every
 * dark surface stay at WCAG AA (4.5 : 1), so any avatar colour works; already-light ones are
 * used as they are. `null` (no rider) gives [OrColors.DefaultAccent].
 */
fun riderAccent(avatarColor: Int?): Color {
    if (avatarColor == null) return OrColors.DefaultAccent
    val base = Color(avatarColor).copy(alpha = 1f)
    var step = 0
    while (step <= 20) {
        val c = lerp(base, Color.White, step / 20f)
        if (accentReadable(c)) return c
        step++
    }
    return OrColors.DefaultAccent
}

/** [OnAccent] text on [accent], and [accent] as text on every dark surface, all at 4.5 : 1. */
fun accentReadable(accent: Color): Boolean =
    contrastRatio(OrColors.OnAccent, accent) >= TEXT &&
        listOf(OrColors.Background, OrColors.Surface, OrColors.SurfaceRaised).all { contrastRatio(accent, it) >= TEXT }
