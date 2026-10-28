package dev.digitalducktape.openride.ui.profile

import dev.digitalducktape.openride.core.heartrate.BlePermissionState
import dev.digitalducktape.openride.core.sensor.ConnectionState

/**
 * What the pairing screen asks for while Bluetooth permission is missing: an explanation and one
 * button. [opensAppSettings] when Android won't show its own prompt again, so the button goes to
 * this app's system Settings page instead of re-requesting.
 */
data class HrPermissionPrompt(
    val message: String,
    val actionLabel: String,
    val opensAppSettings: Boolean,
)

/** The HR pairing screen's derived text and visibility, kept out of the composable for tests. */
object HrPairingLabels {
    /** The paired-strap row's title: its name once the scan has seen one, else its address. */
    fun pairedTitle(pairedAddress: String?, pairedName: String? = null): String =
        if (pairedAddress == null) "No strap paired" else pairedName ?: pairedAddress

    /**
     * The paired-strap row's status line: live once the strap is sending, else what wakes it.
     * A strap only connects while worn (it sleeps without skin contact), and the app keeps
     * trying while it's paired.
     */
    fun pairedStatus(pairedAddress: String?, connection: ConnectionState = ConnectionState.Unavailable, bpm: Int? = null): String =
        when {
            pairedAddress == null -> "Pick a strap from the scan to pair it"
            connection == ConnectionState.Connected && bpm != null -> "Connected  •  $bpm bpm"
            else -> "Paired. Connects when you wear it"
        }

    /** Whether the paired row reads as live (green). */
    fun pairedLive(connection: ConnectionState, bpm: Int?): Boolean = connection == ConnectionState.Connected && bpm != null

    /** The scan button's text. */
    fun scanAction(isScanning: Boolean): String = if (isScanning) "Stop scan" else "Scan for straps"

    /** A found strap's title: its advertised name, if it has one. */
    fun deviceName(name: String?): String = name ?: "Unknown device"

    /** The hint shown when a finished scan found nothing (and nothing went wrong). */
    fun emptyHint(uiState: HrPairingViewModel.UiState): String? =
        if (uiState.nearbyDevices.isEmpty() && !uiState.isScanning && uiState.error == null) {
            "No straps found yet. Make sure yours is in pairing mode and tap Scan."
        } else {
            null
        }

    /** The permission ask for [state], or `null` once Bluetooth permission is granted. */
    fun permissionPrompt(state: BlePermissionState): HrPermissionPrompt? = when (state) {
        BlePermissionState.Granted -> null
        BlePermissionState.NotRequested -> HrPermissionPrompt(
            message = "Bluetooth permission is needed to scan for heart-rate straps.",
            actionLabel = "Grant Bluetooth permission",
            opensAppSettings = false,
        )
        BlePermissionState.ShouldShowRationale -> HrPermissionPrompt(
            message = "OpenRide needs Bluetooth (and, on this device, location) permission to find " +
                "nearby heart-rate straps. It's only used to scan for and connect to the strap you " +
                "pick, never to track your location.",
            actionLabel = "Grant permission",
            opensAppSettings = false,
        )
        BlePermissionState.PermanentlyDenied -> HrPermissionPrompt(
            message = "Bluetooth permission was denied. Heart-rate pairing will stay unavailable " +
                "until it's enabled from this app's system Settings page.",
            actionLabel = "Open Settings",
            opensAppSettings = true,
        )
    }
}
