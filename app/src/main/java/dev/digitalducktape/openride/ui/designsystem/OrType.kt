package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The bike type scale (docs/MAIN_UI_REFRESH.md §0 rule 3 and §3): the system sans, sized to be
 * read from about a metre away. Anything read while riding is at least 18 sp; tracked-caps labels
 * are at least 14 sp; nothing is under 16 sp otherwise.
 *
 * Migrated screens and the design-system components use these styles. `MaterialTheme.typography`
 * stays at Material's defaults until every screen has moved (phase 7), so screens that have not
 * yet been rebuilt keep the layout they were tuned for.
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
    )
}
