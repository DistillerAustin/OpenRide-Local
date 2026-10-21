package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/**
 * The bike's app window (docs/MAIN_UI_REFRESH.md §0). The panel is 1920 × 1080 px at density 1.5,
 * but Android 11 on the tablet keeps the hidden navigation bar's 72 px strip out of every window
 * (issue #57), so the app gets 1920 × 1008 px = 1280 × 672 dp. Layouts are designed for this and
 * must never assume 720 dp of height.
 */
object BikeWindow {
    val Width = 1280.dp
    val Height = 672.dp

    /** The panel strip the tablet reserves below the window (72 px at density 1.5). */
    val ReservedNavStrip = 48.dp
}

/** Spacing on a 4 dp grid. */
object OrSpacing {
    val xs = 4.dp
    val sm = 8.dp
    val md = 16.dp
    val lg = 24.dp
    val xl = 32.dp
    val xxl = 48.dp

    /** Left/right margin of a screen's content. */
    val ScreenGutter = 32.dp
}

/**
 * Control sizes (docs/MAIN_UI_REFRESH.md §3, revised 2026-10-21 after the rider saw the first
 * mockups: the 64/80 dp first pass read as oversized on the 1280 × 672 dp window). 44 dp is about
 * 7 mm at density 1.5, still a thumb's width; nothing tappable is smaller.
 */
object OrSize {
    /** Smallest touch target: chips, toggles, icon buttons. */
    val TouchMin = 44.dp

    /** Ordinary buttons (secondary, accent, danger). */
    val Button = 48.dp

    /** A screen's one primary action (Start ride, Enter Games). */
    val PrimaryAction = 56.dp

    /** The shared top bar ([dev.digitalducktape.openride.ui.designsystem.component.OrTopBar]). */
    val TopBar = 72.dp

    /** The bottom navigation bar: 108 px of the window's 1008. */
    val BottomBar = 72.dp

    val NavIcon = 28.dp

    /** A settings row (title, value, chevron). */
    val SettingsRow = 56.dp

    val IconInline = 24.dp
}

/** Corner radii. */
object OrRadius {
    val sm = 12.dp
    val md = 20.dp
    val lg = 28.dp
}

/** Shapes built from [OrRadius]. */
object OrShapes {
    val Small = RoundedCornerShape(OrRadius.sm)
    val Medium = RoundedCornerShape(OrRadius.md)
    val Large = RoundedCornerShape(OrRadius.lg)
    val Pill = RoundedCornerShape(50)
}
