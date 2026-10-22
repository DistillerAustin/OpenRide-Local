package dev.digitalducktape.openride.ui.update

/**
 * The updates screen's derived text and which step's button shows, kept out of the composable so
 * it can be unit-tested. Each step stays its own explicit tap (Check → Download → Install).
 */
object UpdateLabels {
    /** "Installed: 0.5.1 (build 51)". */
    fun installed(uiState: UpdateViewModel.UiState): String =
        "Installed: ${uiState.currentVersionName} (build ${uiState.currentVersionCode})"

    /** Download shows once a newer release is found, until its APK is downloaded. */
    fun showDownload(uiState: UpdateViewModel.UiState): Boolean =
        uiState.available != null && uiState.downloadedApk == null

    /** Install shows once the APK is downloaded. */
    fun showInstall(uiState: UpdateViewModel.UiState): Boolean = uiState.downloadedApk != null

    /** Check is the screen's main (accent) action only until there is something newer to fetch. */
    fun checkIsMainAction(uiState: UpdateViewModel.UiState): Boolean = uiState.available == null

    /** The notes panel's heading: "What's new in 0.6.0", or a plain one before a release is found. */
    fun notesTitle(uiState: UpdateViewModel.UiState): String =
        uiState.available?.let { "What's new in ${it.versionName}" } ?: "Release notes"
}
