package dev.digitalducktape.openride.ui.update

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.digitalducktape.openride.core.update.AvailableUpdate
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSize
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrAccentButton
import dev.digitalducktape.openride.ui.designsystem.component.OrEyebrow
import dev.digitalducktape.openride.ui.designsystem.component.OrPrimaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSecondaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSpinner
import dev.digitalducktape.openride.ui.designsystem.component.OrTile
import dev.digitalducktape.openride.ui.designsystem.component.OrTopBar
import dev.digitalducktape.openride.ui.theme.OpenRideTheme
import kotlinx.coroutines.launch

/**
 * Self-updater (PRD #22/T22) connected to its [UpdateViewModel]: the Route half. The view
 * model's steps are `suspend` functions, each started here from its own tap; Install hands the
 * downloaded APK to the platform installer, which shows its own confirmation.
 */
@Composable
fun UpdateRoute(
    viewModel: UpdateViewModel,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    UpdateScreen(
        uiState = uiState,
        onCheck = { scope.launch { viewModel.checkForUpdate() } },
        onDownload = { scope.launch { viewModel.downloadUpdate() } },
        // This tap requests the install; the platform installer asks the rider to confirm.
        onInstall = { viewModel.installIntent()?.let { context.startActivity(it) } },
        onDone = onDone,
        modifier = modifier,
    )
}

/**
 * Self-updater, stateless: check the latest GitHub release, download the APK, and hand it to the
 * system installer, so updating the bike's tablet doesn't need ADB. OpenRide also checks on
 * launch and shows a notice in the shell; this screen is the manual entry point.
 *
 * Each step is a separate explicit tap (Check → Download → Install); nothing chains on its own.
 * The installed version, the status and the step buttons on the left; the release notes on the
 * right, the only part that scrolls, so the buttons and Done always stay on screen.
 */
@Composable
fun UpdateScreen(
    uiState: UpdateViewModel.UiState,
    onCheck: () -> Unit,
    onDownload: () -> Unit,
    onInstall: () -> Unit,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize().background(OrColors.Background)) {
        OrTopBar(
            title = "App updates",
            actions = { OrSecondaryButton(text = "Done", onClick = onDone) },
        )
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, top = OrSpacing.sm, bottom = OrSpacing.lg),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.lg),
        ) {
            OrTile(modifier = Modifier.weight(2f).fillMaxHeight()) {
                OrEyebrow(text = "OpenRide")
                Text(
                    text = UpdateLabels.installed(uiState),
                    style = OrType.Title,
                    color = OrColors.OnBackground,
                    modifier = Modifier.padding(top = OrSpacing.sm),
                )
                Text(
                    text = "OpenRide checks GitHub for the latest release.",
                    style = OrType.Body,
                    color = OrColors.OnSurfaceMuted,
                    modifier = Modifier.padding(top = OrSpacing.xs),
                )

                Spacer(Modifier.weight(1f))

                Row(
                    modifier = Modifier.heightIn(min = OrSize.TouchMin),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
                ) {
                    if (uiState.isBusy) OrSpinner()
                    uiState.status?.let {
                        Text(text = it, style = OrType.Subtitle, color = OrColors.OnBackground)
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = OrSpacing.md),
                    horizontalArrangement = Arrangement.spacedBy(OrSpacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (UpdateLabels.checkIsMainAction(uiState)) {
                        OrAccentButton(text = "Check for updates", onClick = onCheck, enabled = !uiState.isBusy)
                    } else {
                        OrSecondaryButton(text = "Check again", onClick = onCheck, enabled = !uiState.isBusy)
                    }
                    if (UpdateLabels.showDownload(uiState)) {
                        OrAccentButton(text = "Download", onClick = onDownload, enabled = !uiState.isBusy)
                    }
                    if (UpdateLabels.showInstall(uiState)) {
                        OrPrimaryButton(text = "Install", onClick = onInstall, enabled = !uiState.isBusy)
                    }
                }
            }

            OrTile(modifier = Modifier.weight(3f).fillMaxHeight()) {
                OrEyebrow(text = UpdateLabels.notesTitle(uiState))
                val notes = uiState.available?.notes
                Text(
                    text = notes ?: "Check for updates to see what's in the latest release.",
                    style = OrType.Body,
                    color = if (notes != null) OrColors.OnBackground else OrColors.OnSurfaceMuted,
                    modifier = Modifier
                        .padding(top = OrSpacing.md)
                        .weight(1f)
                        .verticalScroll(rememberScrollState()),
                )
            }
        }
    }
}

@BikePreview
@Composable
private fun UpdateScreenPreview() {
    OpenRideTheme {
        UpdateScreen(
            uiState = UpdateViewModel.UiState(
                status = "Version 0.6.0 is available",
                available = AvailableUpdate(
                    versionCode = 60,
                    versionName = "0.6.0",
                    apkUrl = "",
                    notes = "New look for every settings screen.\nFixes a crash when a strap disconnects.",
                ),
                currentVersionName = "0.5.1",
                currentVersionCode = 51,
            ),
            onCheck = {},
            onDownload = {},
            onInstall = {},
            onDone = {},
        )
    }
}
