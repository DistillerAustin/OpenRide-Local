package dev.digitalducktape.openride.ui.sources

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.ImeAction
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.digitalducktape.openride.core.content.ContentCategory
import dev.digitalducktape.openride.core.content.ContentSource
import dev.digitalducktape.openride.core.content.ContentSourceType
import dev.digitalducktape.openride.core.content.ResolvedSource
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrAccentButton
import dev.digitalducktape.openride.ui.designsystem.component.OrEyebrow
import dev.digitalducktape.openride.ui.designsystem.component.OrSecondaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSettingsDivider
import dev.digitalducktape.openride.ui.designsystem.component.OrSettingsRow
import dev.digitalducktape.openride.ui.designsystem.component.OrSpinner
import dev.digitalducktape.openride.ui.designsystem.component.OrSwitch
import dev.digitalducktape.openride.ui.designsystem.component.OrTextField
import dev.digitalducktape.openride.ui.designsystem.component.OrTile
import dev.digitalducktape.openride.ui.designsystem.component.OrTopBar
import dev.digitalducktape.openride.ui.theme.OpenRideTheme
import kotlinx.coroutines.launch

/**
 * Content sources connected to its [ContentSourcesViewModel] (the Route half). Holds the pasted
 * text, which is cleared once a source has been added.
 */
@Composable
fun ContentSourcesRoute(
    viewModel: ContentSourcesViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val sources by viewModel.sources.collectAsStateWithLifecycle(initialValue = null)
    val addState by viewModel.addState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var input by remember { mutableStateOf("") }

    ContentSourcesScreen(
        uiState = ContentSourcesUiState(sources = sources, addState = addState),
        input = input,
        onInputChange = { input = it },
        onLookUp = { scope.launch { viewModel.resolve(input) } },
        onConfirmAdd = { category ->
            scope.launch {
                viewModel.confirmAdd(category)
                input = ""
            }
        },
        onCancelAdd = viewModel::cancelAdd,
        onToggleHidden = { source -> scope.launch { viewModel.setHidden(source.id, !source.hidden) } },
        onDelete = { source -> scope.launch { viewModel.deleteCustom(source.id) } },
        onBack = onBack,
        modifier = modifier,
    )
}

/**
 * Content sources, stateless: add your own creators and playlists, and hide the built-in ones you
 * don't ride. Reached from the Profile tab's settings.
 *
 * Adding is two steps, on the left: look a pasted link up, then classify what it resolved to as
 * Workout or Scenic (or cancel). On the right, every source: a switch shows or hides it on the
 * Classes tab, and the rider's own ones can be removed (built-ins can only be hidden, so the
 * original catalog is always one switch away).
 */
@Composable
fun ContentSourcesScreen(
    uiState: ContentSourcesUiState,
    input: String,
    onInputChange: (String) -> Unit,
    onLookUp: () -> Unit,
    onConfirmAdd: (ContentCategory) -> Unit,
    onCancelAdd: () -> Unit,
    onToggleHidden: (ContentSource) -> Unit,
    onDelete: (ContentSource) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize().background(OrColors.Background)) {
        OrTopBar(
            title = "Content sources",
            actions = { OrSecondaryButton(text = "Done", onClick = onBack) },
        )
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, top = OrSpacing.sm, bottom = OrSpacing.lg),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.lg),
        ) {
            AddSourceTile(
                uiState = uiState,
                input = input,
                onInputChange = onInputChange,
                onLookUp = onLookUp,
                onConfirmAdd = onConfirmAdd,
                onCancelAdd = onCancelAdd,
                modifier = Modifier.weight(1f),
            )
            Column(modifier = Modifier.weight(1f).fillMaxHeight()) {
                OrEyebrow(text = "Your sources", modifier = Modifier.padding(start = OrSpacing.md, bottom = OrSpacing.sm))
                val sources = uiState.sources
                when {
                    sources == null -> Unit
                    sources.isEmpty() -> OrTile(modifier = Modifier.fillMaxWidth()) {
                        Text(text = "No sources yet. Look one up to add it.", style = OrType.Body, color = OrColors.OnSurfaceMuted)
                    }
                    else -> LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f, fill = false)
                            .clip(OrShapes.Medium)
                            .background(OrColors.Surface),
                    ) {
                        itemsIndexed(sources, key = { _, source -> source.id }) { index, source ->
                            if (index > 0) OrSettingsDivider()
                            SourceRow(
                                source = source,
                                onToggleHidden = { onToggleHidden(source) },
                                onDelete = { onDelete(source) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AddSourceTile(
    uiState: ContentSourcesUiState,
    input: String,
    onInputChange: (String) -> Unit,
    onLookUp: () -> Unit,
    onConfirmAdd: (ContentCategory) -> Unit,
    onCancelAdd: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val canLookUp = uiState.canLookUp(input)
    OrTile(modifier = modifier) {
        OrEyebrow(text = "Add a creator or playlist")
        Text(
            text = "Paste a YouTube channel link, @handle, or playlist link",
            style = OrType.Body,
            color = OrColors.OnSurfaceMuted,
            modifier = Modifier.padding(top = OrSpacing.sm),
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = OrSpacing.md),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
        ) {
            OrTextField(
                value = input,
                onValueChange = onInputChange,
                placeholder = "@creator or https://youtube.com/…",
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { if (canLookUp) onLookUp() }),
                modifier = Modifier.weight(1f),
            )
            // Top-aligned with the field (whose reserved error line sits below both).
            OrAccentButton(
                text = "Look up",
                onClick = onLookUp,
                enabled = canLookUp,
                modifier = Modifier.padding(top = OrSpacing.xs),
            )
        }

        when (val state = uiState.addState) {
            is AddSourceState.Resolving -> Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
            ) {
                OrSpinner()
                Text(text = "Looking up…", style = OrType.Body, color = OrColors.OnSurfaceMuted)
            }

            is AddSourceState.Failed -> Text(text = state.message, style = OrType.Body, color = OrColors.Warning)

            is AddSourceState.Resolved -> {
                // Local to this resolution: disables the buttons the instant a category is
                // tapped so a double-tap can't fire confirmAdd twice while the first save is
                // still in flight (the DB's unique index blocks the duplicate row, but which
                // category wins would be nondeterministic and no error surfaces). Reset
                // whenever a new Resolved state arrives.
                var isSaving by remember(state) { mutableStateOf(false) }
                Text(
                    text = ContentSourceLabels.addAs(state.source.displayName),
                    style = OrType.Subtitle,
                    color = OrColors.OnBackground,
                )
                Row(
                    modifier = Modifier.padding(top = OrSpacing.md),
                    horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
                ) {
                    OrAccentButton(
                        text = "Workout",
                        onClick = {
                            isSaving = true
                            onConfirmAdd(ContentCategory.Workout)
                        },
                        enabled = !isSaving,
                    )
                    OrAccentButton(
                        text = "Scenic",
                        onClick = {
                            isSaving = true
                            onConfirmAdd(ContentCategory.Scenic)
                        },
                        enabled = !isSaving,
                    )
                    OrSecondaryButton(text = "Cancel", onClick = onCancelAdd, enabled = !isSaving)
                }
            }

            is AddSourceState.Idle -> Unit
        }
    }
}

@Composable
private fun SourceRow(
    source: ContentSource,
    onToggleHidden: () -> Unit,
    onDelete: () -> Unit,
) {
    OrSettingsRow(
        title = source.displayName,
        value = ContentSourceLabels.details(source),
    ) {
        OrSwitch(
            checked = !source.hidden,
            onCheckedChange = { onToggleHidden() },
            contentDescription = "Show ${source.displayName} on the Classes tab",
        )
        // Built-ins can only be hidden — keeping them means a rider can always get the
        // original catalog back without reinstalling.
        if (!source.builtIn) {
            OrSecondaryButton(text = "Remove", onClick = onDelete)
        }
    }
}

private val previewSources = listOf(
    ContentSource(1, ContentSourceType.CHANNEL, "UC1", "Morning Spin Studio", ContentCategory.Workout, builtIn = true, position = 0),
    ContentSource(2, ContentSourceType.CHANNEL, "UC2", "Alpine Rides", ContentCategory.Scenic, builtIn = true, hidden = true, position = 1),
    ContentSource(3, ContentSourceType.PLAYLIST, "PL3", "Tuesday intervals", ContentCategory.Workout, builtIn = false, position = 2),
)

@BikePreview
@Composable
private fun ContentSourcesScreenPreview() {
    OpenRideTheme {
        ContentSourcesScreen(
            uiState = ContentSourcesUiState(
                sources = previewSources,
                addState = AddSourceState.Resolved(ResolvedSource(ContentSourceType.CHANNEL, "UC4", "Coastal Climbs")),
            ),
            input = "@coastalclimbs",
            onInputChange = {},
            onLookUp = {},
            onConfirmAdd = {},
            onCancelAdd = {},
            onToggleHidden = {},
            onDelete = {},
            onBack = {},
        )
    }
}
