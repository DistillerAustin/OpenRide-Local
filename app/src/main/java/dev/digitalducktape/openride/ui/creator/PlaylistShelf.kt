package dev.digitalducktape.openride.ui.creator

/** What a playlist shelf on a creator's page shows (pure, plain-JUnit testable). */
sealed interface PlaylistShelf {
    data object Loading : PlaylistShelf

    data object Failed : PlaylistShelf {
        const val MESSAGE = "Couldn't load this playlist"
    }

    /** Its classes (possibly none, for an empty playlist). */
    data object Videos : PlaylistShelf

    companion object {
        fun of(row: PlaylistRow): PlaylistShelf = when {
            row.isLoading -> Loading
            row.videos.isEmpty() && row.loadFailed -> Failed
            else -> Videos
        }

        /**
         * Each playlist is its own page fetch, so a shelf asks for its content when it is first
         * composed, and only if it has none, isn't already loading and hasn't failed.
         */
        fun needsLoad(row: PlaylistRow): Boolean = row.videos.isEmpty() && !row.isLoading && !row.loadFailed
    }
}
