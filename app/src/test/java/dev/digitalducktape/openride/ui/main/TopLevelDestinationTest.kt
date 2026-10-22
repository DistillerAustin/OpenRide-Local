package dev.digitalducktape.openride.ui.main

import dev.digitalducktape.openride.ui.navigation.MainTabs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The rail must keep every tab the bottom bar had, in the same order (feature parity). */
class TopLevelDestinationTest {

    @Test
    fun `the five tabs keep their order and routes`() {
        assertEquals(
            listOf(MainTabs.Home, MainTabs.Classes, MainTabs.Games, MainTabs.History, MainTabs.Profile),
            TopLevelDestination.entries.map { it.route },
        )
        assertEquals(
            listOf("Home", "Classes", "Games", "History", "Profile"),
            TopLevelDestination.entries.map { it.label },
        )
    }

    @Test
    fun `routes are unique`() {
        val routes = TopLevelDestination.entries.map { it.route }
        assertEquals(routes.size, routes.toSet().size)
    }

    @Test
    fun `the main section opens on Home`() {
        assertEquals(TopLevelDestination.Home, TopLevelDestination.Start)
    }

    @Test
    fun `only the Games tab uses an emoji, the controller it had before`() {
        assertEquals(listOf(TopLevelDestination.Games), TopLevelDestination.entries.filter { it.emoji != null })
        assertEquals("🎮", TopLevelDestination.Games.emoji)
    }

    @Test
    fun `fromRoute finds a tab and ignores other routes`() {
        TopLevelDestination.entries.forEach { assertEquals(it, TopLevelDestination.fromRoute(it.route)) }
        assertNull(TopLevelDestination.fromRoute("in_ride"))
        assertNull(TopLevelDestination.fromRoute(null))
    }
}
