package dev.digitalducktape.openride.ui.profile

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.core.content.ContextCompat
import dev.digitalducktape.openride.core.heartrate.BleDevice
import dev.digitalducktape.openride.core.heartrate.BlePermissionState
import dev.digitalducktape.openride.core.heartrate.reduceBlePermissionState
import dev.digitalducktape.openride.core.heartrate.requiredBlePermissions
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrShapes
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrAccentButton
import dev.digitalducktape.openride.ui.designsystem.component.OrEyebrow
import dev.digitalducktape.openride.ui.designsystem.component.OrSecondaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSettingsDivider
import dev.digitalducktape.openride.ui.designsystem.component.OrSettingsGroup
import dev.digitalducktape.openride.ui.designsystem.component.OrSettingsRow
import dev.digitalducktape.openride.ui.designsystem.component.OrSpinner
import dev.digitalducktape.openride.ui.designsystem.component.OrTile
import dev.digitalducktape.openride.ui.designsystem.component.OrTopBar
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/**
 * BLE heart-rate strap pairing (PRD P1-4, T17) connected to its [HrPairingViewModel]: the Route
 * half, which owns the permission dance. It requests the platform-appropriate BLE runtime
 * permission(s) (see [requiredBlePermissions]) and reduces Android's signals to a
 * [BlePermissionState] with [reduceBlePermissionState]; the stateless [HrPairingScreen] draws it.
 *
 * **Hardware caveat (T17/#17)**: this project has no physical BLE heart-rate strap, so the
 * actual "a real strap shows up in the scan results and pairing sticks" path is unverified —
 * see [dev.digitalducktape.openride.core.heartrate.AndroidBleScanner]'s doc. The permission
 * flow, scan lifecycle, and persistence-to-profile logic are all exercised here and in
 * [HrPairingViewModelTest] against fakes.
 */
@Composable
fun HrPairingRoute(
    viewModel: HrPairingViewModel,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val permissions = remember { requiredBlePermissions() }
    var everRequested by remember { mutableStateOf(false) }

    fun refreshPermissionState() {
        val state = reduceBlePermissionState(
            permissions = permissions,
            granted = { permission ->
                ContextCompat.checkSelfPermission(context, permission) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
            },
            shouldShowRationale = { permission ->
                val activity = context as? android.app.Activity
                activity != null &&
                    androidx.core.app.ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
            },
            everRequested = everRequested,
        )
        viewModel.onPermissionState(state)
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        everRequested = true
        refreshPermissionState()
    }

    LaunchedEffect(Unit) { refreshPermissionState() }

    HrPairingScreen(
        uiState = uiState,
        onRequestPermission = { permissionLauncher.launch(permissions) },
        onOpenAppSettings = {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", context.packageName, null),
            )
            context.startActivity(intent)
        },
        onStartScan = viewModel::startScan,
        onStopScan = viewModel::stopScan,
        onSelectDevice = viewModel::selectDevice,
        onForget = viewModel::forgetDevice,
        onDone = onDone,
        modifier = modifier,
    )
}

/**
 * Heart-rate strap pairing, stateless. The paired strap (with Forget, and "Connected" with the
 * live bpm once it's sending) and the scan controls on the left; on the right the other straps
 * the scan found, each one tap to pair, or, until Bluetooth
 * permission is granted, why it's needed and the one button that gets it (the system prompt, or
 * this app's Settings page once Android stops asking).
 */
@Composable
fun HrPairingScreen(
    uiState: HrPairingViewModel.UiState,
    onRequestPermission: () -> Unit,
    onOpenAppSettings: () -> Unit,
    onStartScan: () -> Unit,
    onStopScan: () -> Unit,
    onSelectDevice: (BleDevice) -> Unit,
    onForget: () -> Unit,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val granted = uiState.permissionState == BlePermissionState.Granted
    Column(modifier = modifier.fillMaxSize().background(OrColors.Background)) {
        OrTopBar(
            title = "Heart-rate strap",
            actions = { OrSecondaryButton(text = "Done", onClick = onDone) },
        )
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, top = OrSpacing.sm, bottom = OrSpacing.lg),
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.lg),
        ) {
            Column(modifier = Modifier.weight(2f), verticalArrangement = Arrangement.spacedBy(OrSpacing.lg)) {
                OrSettingsGroup(title = "Paired strap") {
                    val paired = uiState.pairedAddress != null
                    val live = HrPairingLabels.pairedLive(uiState.strapConnection, uiState.strapBpm)
                    OrSettingsRow(
                        title = HrPairingLabels.pairedTitle(uiState.pairedAddress, uiState.pairedName),
                        value = HrPairingLabels.pairedStatus(uiState.pairedAddress, uiState.strapConnection, uiState.strapBpm),
                        valueColor = if (live) OrColors.Success else OrColors.OnSurfaceMuted,
                        trailing = if (paired) {
                            { OrSecondaryButton(text = "Forget strap", onClick = onForget) }
                        } else {
                            null
                        },
                    )
                }
                if (granted) {
                    ScanTile(
                        isScanning = uiState.isScanning,
                        error = uiState.error,
                        onStartScan = onStartScan,
                        onStopScan = onStopScan,
                    )
                }
            }

            Column(modifier = Modifier.weight(3f)) {
                OrEyebrow(text = "Nearby straps", modifier = Modifier.padding(start = OrSpacing.md, bottom = OrSpacing.sm))
                val prompt = HrPairingLabels.permissionPrompt(uiState.permissionState)
                val emptyHint = HrPairingLabels.emptyHint(uiState)
                when {
                    prompt != null -> OrTile(modifier = Modifier.fillMaxWidth()) {
                        Text(text = prompt.message, style = OrType.Body, color = OrColors.OnBackground)
                        OrAccentButton(
                            text = prompt.actionLabel,
                            onClick = if (prompt.opensAppSettings) onOpenAppSettings else onRequestPermission,
                            modifier = Modifier.padding(top = OrSpacing.lg),
                        )
                    }
                    uiState.nearbyDevices.isNotEmpty() -> DeviceList(devices = uiState.nearbyDevices, onSelectDevice = onSelectDevice)
                    emptyHint != null -> OrTile(modifier = Modifier.fillMaxWidth()) {
                        Text(text = emptyHint, style = OrType.Body, color = OrColors.OnSurfaceMuted)
                    }
                }
            }
        }
    }
}

@Composable
private fun ScanTile(
    isScanning: Boolean,
    error: String?,
    onStartScan: () -> Unit,
    onStopScan: () -> Unit,
) {
    OrTile(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(OrSpacing.md)) {
            OrAccentButton(
                text = HrPairingLabels.scanAction(isScanning),
                onClick = { if (isScanning) onStopScan() else onStartScan() },
            )
            if (isScanning) {
                OrSpinner()
                Text(text = "Scanning…", style = OrType.Body, color = OrColors.OnSurfaceMuted)
            }
        }
        if (error != null) {
            Text(
                text = error,
                style = OrType.Body,
                color = OrColors.Warning,
                modifier = Modifier.padding(top = OrSpacing.md),
            )
        }
    }
}

@Composable
private fun DeviceList(devices: List<BleDevice>, onSelectDevice: (BleDevice) -> Unit) {
    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .clip(OrShapes.Medium)
            .background(OrColors.Surface),
    ) {
        itemsIndexed(devices, key = { _, device -> device.address }) { index, device ->
            if (index > 0) OrSettingsDivider()
            OrSettingsRow(
                title = HrPairingLabels.deviceName(device.name),
                value = device.address,
                onClick = { onSelectDevice(device) },
                trailing = { OrSecondaryButton(text = "Pair", onClick = { onSelectDevice(device) }) },
            )
        }
    }
}

@BikePreview
@Composable
private fun HrPairingScreenPreview() {
    OpenRideTheme {
        HrPairingScreen(
            uiState = HrPairingViewModel.UiState(
                permissionState = BlePermissionState.Granted,
                isScanning = true,
                devices = listOf(BleDevice("C4:7F:51:0A:22:9E", "Chest strap 22"), BleDevice("E1:02:33:44:55:66", null)),
                pairedAddress = "C4:7F:51:0A:22:9E",
            ),
            onRequestPermission = {},
            onOpenAppSettings = {},
            onStartScan = {},
            onStopScan = {},
            onSelectDevice = {},
            onForget = {},
            onDone = {},
        )
    }
}

@BikePreview
@Composable
private fun HrPairingPermissionPreview() {
    OpenRideTheme {
        HrPairingScreen(
            uiState = HrPairingViewModel.UiState(permissionState = BlePermissionState.ShouldShowRationale),
            onRequestPermission = {},
            onOpenAppSettings = {},
            onStartScan = {},
            onStopScan = {},
            onSelectDevice = {},
            onForget = {},
            onDone = {},
        )
    }
}
