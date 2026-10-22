package dev.digitalducktape.openride.ui.update

import dev.digitalducktape.openride.core.update.AvailableUpdate
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdateLabelsTest {

    private val installed = UpdateViewModel.UiState(currentVersionName = "0.5.1", currentVersionCode = 51)
    private val update = AvailableUpdate(versionCode = 60, versionName = "0.6.0", apkUrl = "https://example.invalid/app.apk")

    @Test
    fun `the installed line names the version and build`() {
        assertEquals("Installed: 0.5.1 (build 51)", UpdateLabels.installed(installed))
    }

    @Test
    fun `before a check only Check shows, as the main action`() {
        assertTrue(UpdateLabels.checkIsMainAction(installed))
        assertFalse(UpdateLabels.showDownload(installed))
        assertFalse(UpdateLabels.showInstall(installed))
        assertEquals("Release notes", UpdateLabels.notesTitle(installed))
    }

    @Test
    fun `a found release offers Download, not Install`() {
        val found = installed.copy(available = update)
        assertFalse(UpdateLabels.checkIsMainAction(found))
        assertTrue(UpdateLabels.showDownload(found))
        assertFalse(UpdateLabels.showInstall(found))
        assertEquals("What's new in 0.6.0", UpdateLabels.notesTitle(found))
    }

    @Test
    fun `a downloaded release offers Install instead of Download`() {
        val downloaded = installed.copy(available = update, downloadedApk = File("openride.apk"))
        assertFalse(UpdateLabels.showDownload(downloaded))
        assertTrue(UpdateLabels.showInstall(downloaded))
    }
}
