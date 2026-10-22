package dev.digitalducktape.openride.ui.main

import androidx.compose.ui.graphics.vector.ImageVector
import dev.digitalducktape.openride.ui.designsystem.OrIcons
import dev.digitalducktape.openride.ui.navigation.MainTabs

/**
 * The tabs of the main section, in rail order. [emoji] replaces [icon] where a glyph says it
 * better (the Games tab's controller, as before the refresh).
 */
enum class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: ImageVector,
    val emoji: String? = null,
) {
    Home(MainTabs.Home, "Home", OrIcons.Home),
    Classes(MainTabs.Classes, "Classes", OrIcons.Classes),
    Games(MainTabs.Games, "Games", OrIcons.Games, emoji = "🎮"),
    History(MainTabs.History, "History", OrIcons.History),
    Profile(MainTabs.Profile, "Profile", OrIcons.Profile),
    ;

    companion object {
        /** Where the main section opens. */
        val Start = Home

        /** The destination whose route is [route], or `null` for a route that isn't a tab. */
        fun fromRoute(route: String?): TopLevelDestination? = entries.firstOrNull { it.route == route }
    }
}
