package dev.digitalducktape.openride.core.heartrate

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import dev.digitalducktape.openride.core.sensor.ConnectionState
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Real [HeartRateDataSource] for a single paired BLE strap, over the standard Bluetooth GATT
 * **Heart Rate Service** (`0x180D`) / **Heart Rate Measurement** characteristic (`0x2A37`) —
 * every commodity chest strap and most fitness watches implement this (PRD P1-4, T17).
 *
 * ## Protocol
 * - Connect via [android.bluetooth.BluetoothDevice.connectGatt], discover services, find the
 *   Heart Rate Measurement characteristic, enable notifications on it (write
 *   `ENABLE_NOTIFICATION_VALUE` to its Client Characteristic Configuration descriptor,
 *   `0x2902` — the standard GATT subscribe dance, not anything strap-specific).
 * - Each notification's raw bytes are decoded by [HeartRateParser] (reimplemented from the
 *   public Bluetooth SIG spec).
 *
 * ## Staying connected
 * A strap sleeps until it's worn and drops the link when it's taken off or loses skin contact
 * (on the bike, 2026-10-27, Ed's strap connected and dropped 19 s later with a supervision
 * timeout, and the old one-shot connect never tried again). So from [start] until [stop] this
 * keeps trying, two ways at once:
 * - a background connect (`autoConnect`), which also joins a link another app already holds;
 * - a scan for this strap's address, which catches it the moment it wakes and advertises, and
 *   then connects directly. After a reboot the stack may not know the strap's address type,
 *   which only a scan teaches it.
 *
 * After a live link drops it starts over at once; after a failed attempt, in [RETRY_MS]. Scan
 * starts stay [RETRY_MS] apart either way, under Android's limit of five per 30 s. Every GATT status is logged at W (the tablet's
 * log level), since a failed connect is otherwise silent.
 *
 * ## Connection state
 * Same contract as [dev.digitalducktape.openride.core.sensor.PelotonBikeDataSource]:
 * [ConnectionState.Connected] only once a real frame has been decoded (a GATT connection that
 * never yields data doesn't masquerade as live), [ConnectionState.Disconnected] after a drop
 * from Connected, [ConnectionState.Unavailable] otherwise. [start] never throws.
 */
class BleHeartRateDataSource(
    private val context: Context,
    private val deviceAddress: String,
) : ManagedHeartRateDataSource {

    private val _bpm = MutableStateFlow<Int?>(null)
    override val bpm: StateFlow<Int?> = _bpm.asStateFlow()

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Unavailable)
    override val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    // Every field below is touched only on the main thread: GATT and scan callbacks arrive on
    // binder threads and are posted here.
    private val handler = Handler(Looper.getMainLooper())
    private val adapter: BluetoothAdapter? by lazy {
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    }
    private var running = false
    private var gatt: BluetoothGatt? = null
    private var finder: ScanCallback? = null
    private var lastFinderStart = Long.MIN_VALUE / 2

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt?, status: Int, newState: Int) {
            handler.post { onConnectionChanged(g, status, newState) }
        }

        override fun onServicesDiscovered(g: BluetoothGatt?, status: Int) {
            handler.post { subscribe(g, status) }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(g: BluetoothGatt?, characteristic: BluetoothGattCharacteristic?) {
            // The pre-API-33 callback signature (deprecated but still invoked by the platform
            // on every supported API level here, including 33+) — kept to one overload rather
            // than duplicating logic across both signatures.
            val bytes = characteristic?.value ?: return
            handler.post { if (g === gatt) handleFrame(bytes) }
        }
    }

    /** Starts connecting, and keeps reconnecting until [stop]. Call once. */
    override fun start() {
        handler.post {
            running = true
            connect()
        }
    }

    /** Disconnects and releases the GATT client. Safe to call even if [start] never connected. */
    override fun stop() {
        handler.post {
            running = false
            handler.removeCallbacksAndMessages(null)
            stopFinder()
            releaseGatt()
            _bpm.value = null
            _connectionState.value = ConnectionState.Unavailable
        }
    }

    private fun connect() {
        if (!running || gatt != null) return
        val adapter = adapter
        if (adapter == null || !adapter.isEnabled) {
            Log.w(TAG, "Bluetooth is off or missing; trying again shortly")
            retryLater()
            return
        }
        try {
            val device = adapter.getRemoteDevice(deviceAddress)
            gatt = device.connectGatt(context, true, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } catch (e: SecurityException) {
            Log.w(TAG, "Connect denied — missing BLUETOOTH_CONNECT permission", e)
            return
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "Invalid BLE device address: $deviceAddress", e)
            return
        }
        if (gatt == null) {
            retryLater()
            return
        }
        startFinder(adapter)
    }

    private fun onConnectionChanged(g: BluetoothGatt?, status: Int, newState: Int) {
        if (g == null || g !== gatt) return // a client already released
        if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
            stopFinder()
            try {
                if (!g.discoverServices()) dropAndRetry("discoverServices refused")
            } catch (e: SecurityException) {
                Log.w(TAG, "discoverServices denied", e)
                dropAndRetry("discoverServices denied")
            }
        } else {
            dropAndRetry("link down (status=$status, state=$newState)")
        }
    }

    private fun subscribe(g: BluetoothGatt?, status: Int) {
        if (g == null || g !== gatt) return
        val characteristic = if (status == BluetoothGatt.GATT_SUCCESS) {
            g.getService(HEART_RATE_SERVICE_UUID)?.getCharacteristic(HEART_RATE_MEASUREMENT_UUID)
        } else {
            null
        }
        if (characteristic == null) {
            dropAndRetry("Heart Rate Measurement characteristic not found (status=$status)")
            return
        }
        try {
            g.setCharacteristicNotification(characteristic, true)
            val descriptor = characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG_UUID)
            if (descriptor != null) {
                // The pre-API-33 CCCD-write path (descriptor.value + writeDescriptor(descriptor))
                // is deprecated in favor of writeDescriptor(descriptor, value), but minSdk
                // here is 30, so this is the form that works across this app's whole
                // supported range.
                @Suppress("DEPRECATION")
                run {
                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    g.writeDescriptor(descriptor)
                }
            }
            // Stay as we are until a real frame arrives — see class doc.
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification subscribe denied", e)
            dropAndRetry("subscribe denied")
        }
    }

    private fun handleFrame(bytes: ByteArray) {
        val measurement = try {
            HeartRateParser.parse(bytes)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "Malformed Heart Rate Measurement frame, dropping", e)
            return
        }
        _bpm.value = measurement.bpm
        if (_connectionState.value != ConnectionState.Connected) {
            Log.w(TAG, "Strap $deviceAddress connected")
            _connectionState.value = ConnectionState.Connected
        }
    }

    /**
     * Lets go of the current attempt or link, clears the reading, and tries again: at once after
     * a live link drops (on the bike the strap's link timed out every 30-40 s and came back, so
     * every second waited is a second of the ride without heart rate), else after [RETRY_MS].
     */
    private fun dropAndRetry(reason: String) {
        val wasLive = _connectionState.value == ConnectionState.Connected
        Log.w(TAG, "Strap $deviceAddress: $reason; retrying ${if (wasLive) "now" else "in ${RETRY_MS / 1000} s"}")
        if (wasLive) _connectionState.value = ConnectionState.Disconnected
        _bpm.value = null
        stopFinder()
        releaseGatt()
        if (wasLive) handler.post { connect() } else retryLater()
    }

    private fun retryLater() {
        if (running) handler.postDelayed({ connect() }, RETRY_MS)
    }

    /**
     * Scans for this one strap while the background connect waits. When the strap advertises
     * (it has just woken), the scan's device carries its address type, and a direct connect to
     * it is quick; the background attempt is replaced by that one.
     */
    private fun startFinder(adapter: BluetoothAdapter) {
        if (finder != null) return
        // Scan starts stay [RETRY_MS] apart (Android's five-per-30-s limit), however fast the
        // reconnects come; the background connect covers the wait.
        val wait = lastFinderStart + RETRY_MS - SystemClock.elapsedRealtime()
        if (wait > 0) {
            handler.postDelayed({ if (gatt != null && _connectionState.value != ConnectionState.Connected) startFinder(adapter) }, wait)
            return
        }
        val scanner = adapter.bluetoothLeScanner ?: return
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                val device = result?.device ?: return
                handler.post { onStrapSeen(device) }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.w(TAG, "Strap scan failed (error $errorCode); relying on the background connect")
                handler.post { finder = null }
            }
        }
        val filter = ScanFilter.Builder().setDeviceAddress(deviceAddress).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
        try {
            scanner.startScan(listOf(filter), settings, callback)
            finder = callback
            lastFinderStart = SystemClock.elapsedRealtime()
        } catch (e: SecurityException) {
            Log.w(TAG, "Strap scan denied — missing location/scan permission; relying on the background connect", e)
        }
    }

    private fun onStrapSeen(device: BluetoothDevice) {
        if (!running || finder == null || _connectionState.value == ConnectionState.Connected) return
        stopFinder()
        releaseGatt()
        try {
            gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } catch (e: SecurityException) {
            Log.w(TAG, "Connect denied — missing BLUETOOTH_CONNECT permission", e)
        }
        if (gatt == null) retryLater()
    }

    private fun stopFinder() {
        val callback = finder ?: return
        finder = null
        try {
            adapter?.bluetoothLeScanner?.stopScan(callback)
        } catch (_: SecurityException) {
            // Permission revoked mid-session; the scan dies with it.
        }
    }

    private fun releaseGatt() {
        val g = gatt ?: return
        gatt = null
        try {
            g.disconnect()
            g.close()
        } catch (_: SecurityException) {
            // Permission revoked mid-session — nothing more we can do, just drop the reference.
        }
    }

    private companion object {
        const val TAG = "BleHeartRateDataSource"

        /** Between attempts: long enough that each attempt's scan start stays under Android's
         *  five-per-30-s limit, short enough that a strap put on mid-ride shows up quickly. */
        const val RETRY_MS = 8_000L

        val HEART_RATE_SERVICE_UUID: UUID = UUID.fromString("0000180D-0000-1000-8000-00805F9B34FB")
        val HEART_RATE_MEASUREMENT_UUID: UUID = UUID.fromString("00002A37-0000-1000-8000-00805F9B34FB")

        /** Standard GATT Client Characteristic Configuration Descriptor (CCCD), 0x2902. */
        val CLIENT_CHARACTERISTIC_CONFIG_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    }
}
