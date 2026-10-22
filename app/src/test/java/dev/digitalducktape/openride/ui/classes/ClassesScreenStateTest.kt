package dev.digitalducktape.openride.ui.classes

import dev.digitalducktape.openride.core.content.ChannelSection
import dev.digitalducktape.openride.core.content.ContentCategory
import dev.digitalducktape.openride.core.content.Video
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClassesScreenStateTest {

    private val video = Video("v1", "Climb", "", "Hill Club", 30 * 60, 1)
    private val section = ChannelSection(1, "c1", "Hill Club", ContentCategory.Workout, listOf(video), refreshFailed = false)
    private val emptySection = section.copy(videos = emptyList())
    private val loaded = ClassesUiState.Loaded(listOf(section), anyRefreshFailed = false)

    @Test
    fun `loading shows the spinner and no filter bar`() {
        val state = ClassesScreenState.from(ClassesUiState.Loading, ClassFilters(), emptyList(), null, emptyMap())
        assertEquals(ClassesBody.Loading, state.body)
        assertFalse(state.showFilters)
        assertFalse(state.refreshFailed)
    }

    @Test
    fun `default browse shows a shelf per creator`() {
        val state = ClassesScreenState.from(loaded, ClassFilters(), listOf(section), null, mapOf("v1" to 5L))
        assertEquals(ClassesBody.Shelves(listOf(section)), state.body)
        assertTrue(state.showFilters)
        assertEquals(mapOf("v1" to 5L), state.takenVideos)
    }

    @Test
    fun `a sort or length shows the flat grid`() {
        val filters = ClassFilters(sort = ClassSort.Oldest)
        val state = ClassesScreenState.from(loaded, filters, listOf(section), listOf(video), emptyMap())
        assertEquals(ClassesBody.Grid(listOf(video)), state.body)
    }

    @Test
    fun `nothing at all offers retry`() {
        val state = ClassesScreenState.from(loaded, ClassFilters(), listOf(emptySection), null, emptyMap())
        val body = state.body as ClassesBody.Empty
        assertFalse(body.filtered)
        assertTrue(body.showRetry)
        assertEquals("No classes available right now. Check your connection and try again", body.message)
    }

    @Test
    fun `a filter that matches nothing says so and offers no retry`() {
        val filters = ClassFilters(length = LengthFilter.Over45)
        val state = ClassesScreenState.from(loaded, filters, listOf(section), emptyList(), emptyMap())
        val body = state.body as ClassesBody.Empty
        assertTrue(body.filtered)
        assertFalse(body.showRetry)
        assertEquals("No classes match these filters", body.message)
    }

    @Test
    fun `a failed refresh keeps the content and raises the banner`() {
        val failed = loaded.copy(anyRefreshFailed = true)
        val state = ClassesScreenState.from(failed, ClassFilters(), listOf(section), null, emptyMap())
        assertTrue(state.refreshFailed)
        assertTrue(state.body is ClassesBody.Shelves)
    }

    @Test
    fun `the length chip reads Any length when unset`() {
        assertEquals("Any length", ClassesScreenState.lengthChipLabel(LengthFilter.Any))
        assertEquals("20–30 min", ClassesScreenState.lengthChipLabel(LengthFilter.From20To30))
        val state = ClassesScreenState(ClassesBody.Loading, ClassFilters(length = LengthFilter.Under20))
        assertEquals("< 20 min", state.lengthLabel)
    }
}
