package dev.digitalducktape.openride.ui.profile

import dev.digitalducktape.openride.core.heartrate.BleDevice
import dev.digitalducktape.openride.core.heartrate.BlePermissionState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HrPairingLabelsTest {

    @Test
    fun `the paired row names the strap or says none is paired`() {
        assertEquals("AA:BB", HrPairingLabels.pairedTitle("AA:BB"))
        assertEquals("No strap paired", HrPairingLabels.pairedTitle(null))
        assertTrue(HrPairingLabels.pairedStatus("AA:BB").startsWith("Paired"))
    }

    @Test
    fun `the scan button toggles between scan and stop`() {
        assertEquals("Scan for straps", HrPairingLabels.scanAction(isScanning = false))
        assertEquals("Stop scan", HrPairingLabels.scanAction(isScanning = true))
    }

    @Test
    fun `an unnamed strap is shown as an unknown device`() {
        assertEquals("Unknown device", HrPairingLabels.deviceName(null))
        assertEquals("Chest strap", HrPairingLabels.deviceName("Chest strap"))
    }

    @Test
    fun `the empty hint shows only after a scan that found nothing and failed nothing`() {
        val idle = HrPairingViewModel.UiState(permissionState = BlePermissionState.Granted)
        assertNotNull(HrPairingLabels.emptyHint(idle))
        assertNull(HrPairingLabels.emptyHint(idle.copy(isScanning = true)))
        assertNull(HrPairingLabels.emptyHint(idle.copy(error = "Bluetooth is off or unavailable")))
        assertNull(HrPairingLabels.emptyHint(idle.copy(devices = listOf(BleDevice("AA:BB", null)))))
    }

    @Test
    fun `every missing-permission state has a prompt, and only permanent denial goes to Settings`() {
        assertNull(HrPairingLabels.permissionPrompt(BlePermissionState.Granted))

        val first = HrPairingLabels.permissionPrompt(BlePermissionState.NotRequested)!!
        assertEquals("Grant Bluetooth permission", first.actionLabel)
        assertFalse(first.opensAppSettings)

        val rationale = HrPairingLabels.permissionPrompt(BlePermissionState.ShouldShowRationale)!!
        assertEquals("Grant permission", rationale.actionLabel)
        assertFalse(rationale.opensAppSettings)
        assertTrue(rationale.message.contains("never to track your location"))

        val denied = HrPairingLabels.permissionPrompt(BlePermissionState.PermanentlyDenied)!!
        assertEquals("Open Settings", denied.actionLabel)
        assertTrue(denied.opensAppSettings)
    }
}
