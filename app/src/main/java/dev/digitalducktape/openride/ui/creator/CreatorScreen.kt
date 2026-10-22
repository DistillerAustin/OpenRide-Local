package dev.digitalducktape.openride.ui.creator

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.digitalducktape.openride.core.content.PlaylistSummary
import dev.digitalducktape.openride.core.content.Video
import dev.digitalducktape.openride.ui.classes.VideoShelf
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrBanner
import dev.digitalducktape.openride.ui.designsystem.component.OrBannerTone
import dev.digitalducktape.openride.ui.designsystem.component.OrEmptyState
import dev.digitalducktape.openride.ui.designsystem.component.OrLoading
import dev.digitalducktape.openride.ui.designsystem.component.OrScreenHeader
import dev.digitalducktape.openride.ui.designsystem.component.OrSpinner
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * A creator's page, connected to its [CreatorViewModel] (the Route half of the Route/Screen
 * split): loads the creator on entry and only navigates to a video ride when the view model
 * actually started one.
 */
@Composable
fun CreatorRoute(
    viewModel: CreatorViewModel,
    onStartVideoRide: (videoId: String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val takenVideos by viewModel.takenVideos.collectAsStateWithLifecycle(initialValue = emptyMap())

    LaunchedEffect(Unit) { viewModel.load() }

    CreatorScreen(
        uiState = uiState,
        takenVideos = takenVideos,
        onVideoSelected = { video -> if (viewModel.startRideForVideo(video.id)) onStartVideoRide(video.id) },
        onPlaylistVisible = { playlistId -> viewModel.loadPlaylist(playlistId) },
        onBack = onBack,
        modifier = modifier,
    )
}

/**
 * The entry point `OpenRideNavHost` still calls; forwards to [CreatorRoute]. Remove once the nav
 * host calls [CreatorRoute] directly.
 */
@Composable
fun CreatorScreen(
    viewModel: CreatorViewModel,
    onStartVideoRide: (videoId: String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) = CreatorRoute(viewModel, onStartVideoRide, onBack, modifier)

/**
 * A creator's page, stateless, reached by tapping their shelf name on the Classes tab: a header
 * with Back and their name, then a LATEST shelf of their recent classes and one shelf per
 * playlist they've curated. Back is always there, even when the creator has gone.
 */
@Composable
fun CreatorScreen(
    uiState: CreatorUiState,
    takenVideos: Map<String, Long>,
    onVideoSelected: (Video) -> Unit,
    onPlaylistVisible: suspend (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(OrColors.Background)
            .padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, bottom = OrSpacing.lg),
    ) {
        OrScreenHeader(
            title = (uiState as? CreatorUiState.Loaded)?.displayName ?: "Creator",
            onBack = onBack,
            backLabel = "Classes",
        )
        when (uiState) {
            CreatorUiState.Loading -> OrLoading()
            // A rider stranded here (their source was deleted while they navigated) still has Back.
            CreatorUiState.NotFound -> OrEmptyState(message = "That creator is no longer in your catalog")
            is CreatorUiState.Loaded -> LoadedCreator(
                state = uiState,
                takenVideos = takenVideos,
                onVideoSelected = onVideoSelected,
                onPlaylistVisible = onPlaylistVisible,
            )
        }
    }
}

@Composable
private fun LoadedCreator(
    state: CreatorUiState.Loaded,
    takenVideos: Map<String, Long>,
    onVideoSelected: (Video) -> Unit,
    onPlaylistVisible: suspend (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(OrSpacing.sm)) {
        if (state.refreshFailed) {
            OrBanner(text = "Couldn't refresh this creator. Showing the last saved list", tone = OrBannerTone.Warning)
        }
        LazyColumn(contentPadding = PaddingValues(bottom = OrSpacing.lg)) {
            item {
                VideoShelf(
                    title = "Latest",
                    videos = state.latest,
                    takenVideos = takenVideos,
                    onVideoSelected = onVideoSelected,
                )
            }
            items(state.playlistRows, key = { it.playlist.id }) { row ->
                LaunchedEffect(row.playlist.id) {
                    if (PlaylistShelf.needsLoad(row)) onPlaylistVisible(row.playlist.id)
                }
                val shelf = PlaylistShelf.of(row)
                VideoShelf(
                    title = row.playlist.title,
                    videos = row.videos,
                    takenVideos = takenVideos,
                    onVideoSelected = onVideoSelected,
                    body = when (shelf) {
                        PlaylistShelf.Loading -> {
                            { OrSpinner(modifier = Modifier.padding(top = OrSpacing.sm), size = OrSize.IconInline + OrSpacing.xs) }
                        }
                        PlaylistShelf.Failed -> {
                            {
                                Box(Modifier.fillMaxWidth().padding(top = OrSpacing.xs)) {
                                    Text(text = PlaylistShelf.Failed.MESSAGE, style = OrType.Body, color = OrColors.OnSurfaceMuted)
                                }
                            }
                        }
                        PlaylistShelf.Videos -> null
                    },
                )
            }
        }
    }
}

@BikePreview
@Composable
private fun CreatorScreenPreview() {
    val video = Video("a", "45 min climb, steady tempo", "", "Hill Club", 45 * 60, 1)
    OpenRideTheme {
        CreatorScreen(
            uiState = CreatorUiState.Loaded(
                displayName = "Hill Club",
                latest = listOf(video, video.copy(id = "b", title = "20 min intervals")),
                playlistRows = listOf(
                    PlaylistRow(PlaylistSummary("p1", "Climbs", "", 12), isLoading = true),
                    PlaylistRow(PlaylistSummary("p2", "Recovery", "", 4), loadFailed = true),
                ),
                refreshFailed = true,
            ),
            takenVideos = emptyMap(),
            onVideoSelected = {},
            onPlaylistVisible = {},
            onBack = {},
        )
    }
}
