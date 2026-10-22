package dev.digitalducktape.openride.ui.sources

import dev.digitalducktape.openride.core.content.ContentSource
import dev.digitalducktape.openride.core.content.ContentSourceType

/**
 * Everything the Content sources screen renders, as one value.
 *
 * @param sources every configured source, or `null` until the database has answered (so "no
 *   sources" never flashes past a list that exists).
 * @param addState where the look-up-then-classify flow is.
 */
data class ContentSourcesUiState(
    val sources: List<ContentSource>? = null,
    val addState: AddSourceState = AddSourceState.Idle,
) {
    /** True once loaded with nothing configured (built-ins can only be hidden, so this is a
     *  database that hasn't been seeded yet). */
    val isEmpty: Boolean get() = sources?.isEmpty() == true

    /** Look up is offered for a non-blank [input] while no look-up is in flight. */
    fun canLookUp(input: String): Boolean = input.isNotBlank() && addState !is AddSourceState.Resolving
}

/** The Content sources screen's derived text, kept out of the composable so it can be unit-tested. */
object ContentSourceLabels {
    /** "Playlist  •  Workout  •  Built in": what a source is, its category, and whether it shipped with the app. */
    fun details(source: ContentSource): String = buildString {
        append(if (source.sourceType == ContentSourceType.PLAYLIST) "Playlist" else "Channel")
        append("  •  ")
        append(source.category.name)
        if (source.builtIn) append("  •  Built in")
        if (source.hidden) append("  •  Hidden")
    }

    /** The question asked once a pasted link resolves. */
    fun addAs(displayName: String): String = "Add \"$displayName\" as:"
}
