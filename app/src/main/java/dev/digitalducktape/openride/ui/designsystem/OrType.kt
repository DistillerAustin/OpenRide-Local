package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The bike type scale (docs/MAIN_UI_REFRESH.md §0 rule 3 and §3): the system sans, sized to be
 * read from about a metre away. Anything read while riding is at least 18 sp; tracked-caps labels
 * are at least 14 sp; nothing is under 16 sp otherwise.
 *
 * Every screen and design-system component uses these styles. `MaterialTheme.typography` is
 * built from them too (`OpenRideTypography`), so Material's own text has the same floors.
 */
object OrType {
    /** A screen's title, in the shared top bar ("Home", "History"). */
    val ScreenTitle = TextStyle(fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)

    /** A tile's or section's title ("Just ride"). */
    val Title = TextStyle(fontSize = 24.sp, lineHeight = 30.sp, fontWeight = FontWeight.Bold)

    /** A row's title, a dialog heading. */
    val Subtitle = TextStyle(fontSize = 20.sp, lineHeight = 26.sp, fontWeight = FontWeight.SemiBold)

    /** Body copy. */
    val Body = TextStyle(fontSize = 18.sp, lineHeight = 26.sp, fontWeight = FontWeight.Normal)

    /** Secondary copy: captions, values in settings rows. Not for anything read mid-ride. */
    val Caption = TextStyle(fontSize = 16.sp, lineHeight = 22.sp, fontWeight = FontWeight.Normal)

    /** Button text. */
    val Button = TextStyle(fontSize = 18.sp, lineHeight = 22.sp, fontWeight = FontWeight.Bold)

    /** The primary action's text (Start ride). */
    val ButtonLarge = TextStyle(fontSize = 22.sp, lineHeight = 26.sp, fontWeight = FontWeight.Bold)

    /** Bottom navigation labels. */
    val NavLabel = TextStyle(fontSize = 18.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold)

    /** Tracked-caps label above a title or a number. Callers pass uppercase text. */
    val Eyebrow = TextStyle(fontSize = 14.sp, lineHeight = 18.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.6.sp)

    /** Small badge text (BETA). */
    val Badge = TextStyle(fontSize = 14.sp, lineHeight = 18.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)

    /** A big number in a stat block (history totals, summary). */
    val StatValue = TextStyle(fontSize = 36.sp, lineHeight = 40.sp, fontWeight = FontWeight.Bold)

    // The ride screens' numbers (issue #60): read mid-ride from about a metre, so the live
    // readings are 48 sp and up, and the supporting ones (AVG / BEST, the second strip) 28 sp.

    /** Just Ride's current output, centre screen. */
    val MetricHero = TextStyle(fontSize = 112.sp, lineHeight = 116.sp, fontWeight = FontWeight.Bold)

    /** The three big current readings in the metrics bar (cadence, output, resistance). */
    val MetricPrimary = TextStyle(fontSize = 72.sp, lineHeight = 76.sp, fontWeight = FontWeight.Bold)

    /** Just Ride's elapsed timer. */
    val MetricTimer = TextStyle(fontSize = 56.sp, lineHeight = 60.sp, fontWeight = FontWeight.Bold)

    /** The video ride's elapsed timer, in the strip over the video. */
    val MetricTimerCompact = TextStyle(fontSize = 48.sp, lineHeight = 52.sp, fontWeight = FontWeight.Bold)

    /** The metrics bar's second strip: speed, distance, total output, heart rate. */
    val MetricSecondary = TextStyle(fontSize = 32.sp, lineHeight = 36.sp, fontWeight = FontWeight.Bold)

    /** AVG and BEST beside each primary reading. */
    val MetricFlank = TextStyle(fontSize = 28.sp, lineHeight = 32.sp, fontWeight = FontWeight.SemiBold)

    /** Every style, for the size-floor tests. */
    val all: Map<String, TextStyle> = mapOf(
        "ScreenTitle" to ScreenTitle,
        "Title" to Title,
        "Subtitle" to Subtitle,
        "Body" to Body,
        "Caption" to Caption,
        "Button" to Button,
        "ButtonLarge" to ButtonLarge,
        "NavLabel" to NavLabel,
        "Eyebrow" to Eyebrow,
        "Badge" to Badge,
        "StatValue" to StatValue,
        "MetricHero" to MetricHero,
        "MetricPrimary" to MetricPrimary,
        "MetricTimer" to MetricTimer,
        "MetricTimerCompact" to MetricTimerCompact,
        "MetricSecondary" to MetricSecondary,
        "MetricFlank" to MetricFlank,
    )
}
