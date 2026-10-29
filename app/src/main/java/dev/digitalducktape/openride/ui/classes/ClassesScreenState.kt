package dev.digitalducktape.openride.ui.classes

import dev.digitalducktape.openride.core.content.ChannelSection
import dev.digitalducktape.openride.core.content.Video

/**
 * Everything the stateless [ClassesScreen] draws, in one value, mapped from the view model's
 * flows by [from] (pure, plain-JUnit testable). [ClassesUiState] stays the view model's own
 * loading state; this adds the filters, the chosen layout and the taken badges.
 */
data class ClassesScreenState(
    val body: ClassesBody,
    val filters: ClassFilters = ClassFilters(),
    /** Some channel's live feed failed and cached content is showing: the refresh-failed banner. */
    val refreshFailed: Boolean = false,
    /** Local NAS availability is independent of the YouTube source refresh. */
    val localLibraryError: String? = null,
    /** Video id to when the active rider last finished it, for the TAKEN badge. */
    val takenVideos: Map<String, Long> = emptyMap(),
) {
    /** The filter bar and banner only show once the catalog has loaded. */
    val showFilters: Boolean get() = body !is ClassesBody.Loading

    /** The length dropdown's label: "Any length" rather than a bare "Any". */
    val lengthLabel: String get() = lengthChipLabel(filters.length)

    companion object {
        const val REFRESH_FAILED_MESSAGE = "Couldn't refresh one or more channels. Showing the last saved list"

        fun lengthChipLabel(length: LengthFilter): String =
            if (length == LengthFilter.Any) "Any length" else length.label

        /**
         * Picks the layout: a spinner while loading; per-creator shelves in the default browse
         * ([gridVideos] `null`); the flat grid once a sort or length is chosen; an empty state
         * (filtered or not) when there's nothing to show in either.
         */
        fun from(
            uiState: ClassesUiState,
            filters: ClassFilters,
            rows: List<ChannelSection>,
            gridVideos: List<Video>?,
            takenVideos: Map<String, Long>,
        ): ClassesScreenState = when (uiState) {
            ClassesUiState.Loading -> ClassesScreenState(body = ClassesBody.Loading, filters = filters, takenVideos = takenVideos)
            is ClassesUiState.Loaded -> {
                val hasAnything = gridVideos?.isNotEmpty() ?: rows.any { it.videos.isNotEmpty() }
                val body = when {
                    !hasAnything -> ClassesBody.Empty(filtered = !filters.isDefaultBrowse)
                    gridVideos != null -> ClassesBody.Grid(gridVideos)
                    else -> ClassesBody.Shelves(rows)
                }
                ClassesScreenState(body = body, filters = filters, refreshFailed = uiState.anyRefreshFailed, localLibraryError = uiState.localLibraryError, takenVideos = takenVideos)
            }
        }
    }
}

/** What fills the Classes tab under its filter bar. */
sealed interface ClassesBody {
    data object Loading : ClassesBody

    /** One shelf per configured creator (default browse). */
    data class Shelves(val sections: List<ChannelSection>) : ClassesBody

    /** Every matching class across creators (a sort or length is chosen). */
    data class Grid(val videos: List<Video>) : ClassesBody

    /**
     * Nothing to show. A filter that matched nothing is a different problem from no content at
     * all, which offers Retry.
     */
    data class Empty(val filtered: Boolean) : ClassesBody {
        val message: String
            get() = if (filtered) {
                "No classes match these filters"
            } else {
                "No classes available right now. Check your connection and try again"
            }
        val showRetry: Boolean get() = !filtered
    }
}
