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
 * Sizes tuned for a rider about a metre away, mid-pedal stroke (§0 rules 2 and 3). Material's
 * 48 dp minimum is a desk number; on the bike 64 dp (96 px, about 10 mm) is the floor.
 */
object OrSize {
    /** Smallest touch target for anything tapped while riding. */
    val TouchMin = 64.dp

    /** A screen's one primary action (Start ride, Enter Games). */
    val PrimaryAction = 80.dp

    /** Width of the left navigation rail. */
    val RailWidth = 120.dp

    /** Height of one rail destination: five of them fit in [BikeWindow.Height] with room spare. */
    val RailItemHeight = 104.dp

    val RailIcon = 36.dp

    /** A settings row (title, value, chevron). */
    val SettingsRow = 72.dp

    val IconInline = 28.dp
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
