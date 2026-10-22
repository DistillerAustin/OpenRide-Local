package dev.digitalducktape.openride.ui.main

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.component.OrAccentButton
import dev.digitalducktape.openride.ui.designsystem.component.OrBanner
import dev.digitalducktape.openride.ui.designsystem.component.OrBannerTone
import dev.digitalducktape.openride.ui.designsystem.component.OrSecondaryButton

/** The sensors-offline notice (issue #56): what's wrong and what to try, in one line. */
const val SensorOfflineText = "Bike sensors aren't responding. Switch the bike off for 30 s, then check the tablet cable."

/**
 * The app-wide notices, under the shared top bar on every tab, so each screen is laid out to
 * leave room for them rather than drawing its own: sensors offline (warning, first), then an
 * available update (info, dismissible). Draws nothing when there's nothing to say.
 */
@Composable
fun AppNotices(
    sensorsOffline: Boolean,
    updateVersionName: String?,
    onOpenUpdate: () -> Unit,
    onDismissUpdate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (!sensorsOffline && updateVersionName == null) return
    Column(
        modifier = modifier.padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, bottom = OrSpacing.sm),
        verticalArrangement = Arrangement.spacedBy(OrSpacing.sm),
    ) {
        if (sensorsOffline) {
            OrBanner(text = SensorOfflineText, tone = OrBannerTone.Warning)
        }
        if (updateVersionName != null) {
            // PRD #22/T22: nothing installs without an explicit tap on the App updates screen.
            OrBanner(text = "OpenRide $updateVersionName is available") {
                OrSecondaryButton(text = "Dismiss", onClick = onDismissUpdate)
                OrAccentButton(text = "Update", onClick = onOpenUpdate)
            }
        }
    }
}
