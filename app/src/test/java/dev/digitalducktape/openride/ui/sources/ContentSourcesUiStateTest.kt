package dev.digitalducktape.openride.ui.sources

import dev.digitalducktape.openride.core.content.ContentCategory
import dev.digitalducktape.openride.core.content.ContentSource
import dev.digitalducktape.openride.core.content.ContentSourceType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ContentSourcesUiStateTest {

    private fun source(
        type: ContentSourceType = ContentSourceType.CHANNEL,
        category: ContentCategory = ContentCategory.Workout,
        builtIn: Boolean = false,
        hidden: Boolean = false,
    ) = ContentSource(1, type, "UC1", "Somebody", category, builtIn = builtIn, hidden = hidden, position = 0)

    @Test
    fun `details read the kind, the category and where it came from`() {
        assertEquals("Channel  •  Workout", ContentSourceLabels.details(source()))
        assertEquals(
            "Playlist  •  Scenic  •  Built in",
            ContentSourceLabels.details(source(ContentSourceType.PLAYLIST, ContentCategory.Scenic, builtIn = true)),
        )
        assertEquals("Channel  •  Workout  •  Hidden", ContentSourceLabels.details(source(hidden = true)))
    }

    @Test
    fun `the resolved prompt quotes the name`() {
        assertEquals("Add \"Somebody\" as:", ContentSourceLabels.addAs("Somebody"))
    }

    @Test
    fun `empty means loaded with nothing, not still loading`() {
        assertFalse(ContentSourcesUiState(sources = null).isEmpty)
        assertTrue(ContentSourcesUiState(sources = emptyList()).isEmpty)
        assertFalse(ContentSourcesUiState(sources = listOf(source())).isEmpty)
    }

    @Test
    fun `look up needs some text and no look-up in flight`() {
        val idle = ContentSourcesUiState()
        assertFalse(idle.canLookUp("  "))
        assertTrue(idle.canLookUp("@someone"))
        assertFalse(idle.copy(addState = AddSourceState.Resolving).canLookUp("@someone"))
        assertTrue(idle.copy(addState = AddSourceState.Failed("No connection — try again")).canLookUp("@someone"))
    }
}
