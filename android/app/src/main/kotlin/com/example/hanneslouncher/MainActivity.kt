package com.example.hanneslouncher

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.Cursor
import android.graphics.Rect
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val gestureChannelName = "hanneslouncher/system_gestures"
    private val calendarChannelName = "hanneslouncher/calendar"
    private val systemAppsChannelName = "hanneslouncher/system_apps"
    private val backupChannelName = "hanneslouncher/backup"
    private val deviceStatsChannelName = "hanneslouncher/device_stats"
    private val calendarPermissionRequestCode = 4201
    private val importFileRequestCode = 4202
    private val stepsPermissionRequestCode = 4203

    // A plugin (device_calendar) returning every field as null on some
    // Android versions is what this replaces - reading Android's own
    // CalendarContract directly, with no library in between to disagree
    // with the platform about column types.
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingImportResult: MethodChannel.Result? = null
    private var pendingStepsPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, gestureChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setExclusionRect" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val left = (call.argument<Double>("left") ?: 0.0).toInt()
                            val top = (call.argument<Double>("top") ?: 0.0).toInt()
                            val right = (call.argument<Double>("right") ?: 0.0).toInt()
                            val bottom = (call.argument<Double>("bottom") ?: 0.0).toInt()
                            window.decorView.systemGestureExclusionRects =
                                listOf(Rect(left, top, right, bottom))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, calendarChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasCalendarPermission())
                    "requestPermission" -> {
                        if (hasCalendarPermission()) {
                            result.success(true)
                        } else {
                            // A stale request (e.g. a very fast double tap)
                            // must not be left to hang forever - it loses,
                            // the new one takes over.
                            pendingPermissionResult?.success(false)
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_CALENDAR),
                                calendarPermissionRequestCode,
                            )
                        }
                    }
                    "getCalendars" -> {
                        result.success(
                            if (hasCalendarPermission()) queryCalendars() else emptyList<Map<String, Any?>>(),
                        )
                    }
                    "getEvents" -> {
                        val calendarIds =
                            (call.argument<List<String>>("calendarIds") ?: emptyList()).toSet()
                        val start = (call.argument<Number>("start") ?: 0).toLong()
                        val end = (call.argument<Number>("end") ?: 0).toLong()
                        result.success(
                            if (hasCalendarPermission()) {
                                queryEvents(calendarIds, start, end)
                            } else {
                                emptyList<Map<String, Any?>>()
                            },
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        // Opens the device's default clock/calendar app, the same way the
        // stock status bar clock does - not by guessing a package name
        // (which varies by OEM) but through the intents/categories Android
        // itself resolves to whatever app is registered as the default.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemAppsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // ACTION_SHOW_ALARMS is what SystemUI fires when the
                    // status bar clock is tapped; every clock app is
                    // expected to handle it per the CTS "AlarmClock" contract.
                    "openClock" -> result.success(
                        startIfResolvable(Intent("android.intent.action.SHOW_ALARMS")),
                    )
                    "openCalendar" -> result.success(
                        startIfResolvable(
                            Intent(Intent.ACTION_MAIN)
                                .addCategory(Intent.CATEGORY_APP_CALENDAR),
                        ),
                    )
                    else -> result.notImplemented()
                }
            }

        // A settings backup as a real file, so it can go through Android's
        // own share sheet (Drive, email, Files, ...) and come back the same
        // way - rather than a plugin dependency for the one-off job of
        // sending/picking a single file.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "export" -> {
                        val json = call.argument<String>("json")
                        result.success(if (json == null) false else exportAndShare(json))
                    }
                    "import" -> {
                        pendingImportResult?.success(null)
                        pendingImportResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, importFileRequestCode)
                    }
                    else -> result.notImplemented()
                }
            }

        // Device-local numbers for the widget placeholders in
        // data_packages_controller.dart - each queried fresh on every call
        // rather than kept updating in the background, since a panel
        // opened once in a while has no use for a live stream of them.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceStatsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "battery" -> result.success(batteryInfo())
                    "storage" -> result.success(storageInfo())
                    "connectionType" -> result.success(connectionType())
                    "hasStepsPermission" -> result.success(hasStepsPermission())
                    "requestStepsPermission" -> {
                        if (hasStepsPermission()) {
                            result.success(true)
                        } else {
                            pendingStepsPermissionResult?.success(false)
                            pendingStepsPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                                stepsPermissionRequestCode,
                            )
                        }
                    }
                    "stepCounterRaw" -> readStepCounter(result)
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "requestUsageAccess" -> {
                        // Not grantable through a runtime prompt - this is
                        // the one and only way an app can be turned on in
                        // the system's "Usage access" list.
                        startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    "mostUsedApp" -> result.success(mostUsedAppToday())
                    else -> result.notImplemented()
                }
            }
    }

    private fun batteryInfo(): Map<String, Any?> {
        // A sticky broadcast - registering for it with a null receiver hands
        // back the last one immediately, so this reads as a plain
        // synchronous query instead of an actual broadcast subscription.
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val percent = if (level >= 0 && scale > 0) level * 100 / scale else -1
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging =
            status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
        return mapOf("percent" to percent, "charging" to charging)
    }

    private fun storageInfo(): Map<String, Any?> {
        // filesDir sits on the internal storage partition, so its free/total
        // space is the device's own, not some per-app quota.
        return mapOf(
            "freeBytes" to filesDir.freeSpace,
            "totalBytes" to filesDir.totalSpace,
        )
    }

    private fun connectionType(): String {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return "none"
        val caps = cm.getNetworkCapabilities(network) ?: return "none"
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
    }

    private fun hasStepsPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACTIVITY_RECOGNITION,
        ) == PackageManager.PERMISSION_GRANTED

    /// The step counter sensor only reports on change, not on demand - this
    /// registers a listener just long enough to catch the next (usually
    /// near-immediate) reading, then drops it again. A timeout answers with
    /// null instead of hanging forever if the device never fires one (no
    /// sensor, or one that's stuck).
    private fun readStepCounter(result: MethodChannel.Result) {
        if (!hasStepsPermission()) {
            result.success(null)
            return
        }
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            result.success(null)
            return
        }
        var answered = false
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (answered) return
                answered = true
                sensorManager.unregisterListener(this)
                result.success(event.values[0].toInt())
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        Handler(Looper.getMainLooper()).postDelayed({
            if (!answered) {
                answered = true
                sensorManager.unregisterListener(listener)
                result.success(null)
            }
        }, 3000)
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName,
                )
            }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun mostUsedAppToday(): String? {
        if (!hasUsageAccess()) return null
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val midnight =
            Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        val top =
            usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, midnight.timeInMillis, end)
                ?.filter { it.totalTimeInForeground > 0 && it.packageName != packageName }
                ?.maxByOrNull { it.totalTimeInForeground }
                ?: return null
        return try {
            val appInfo = packageManager.getApplicationInfo(top.packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            top.packageName
        }
    }

    private fun exportAndShare(json: String): Boolean {
        return try {
            val backupDir = File(filesDir, "backup")
            if (!backupDir.exists()) backupDir.mkdirs()
            val file = File(backupDir, "hanneslouncher_backup.json")
            file.writeText(json)
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/json"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, null))
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == importFileRequestCode) {
            val result = pendingImportResult
            pendingImportResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result?.success(null)
                return
            }
            try {
                val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                result?.success(text)
            } catch (e: Exception) {
                result?.success(null)
            }
        }
    }

    private fun startIfResolvable(intent: Intent): Boolean {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return if (packageManager.resolveActivity(intent, 0) != null) {
            startActivity(intent)
            true
        } else {
            false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted =
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (requestCode == calendarPermissionRequestCode) {
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        } else if (requestCode == stepsPermissionRequestCode) {
            pendingStepsPermissionResult?.success(granted)
            pendingStepsPermissionResult = null
        }
    }

    private fun hasCalendarPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_CALENDAR,
        ) == PackageManager.PERMISSION_GRANTED

    private fun queryCalendars(): List<Map<String, Any?>> {
        val calendars = mutableListOf<Map<String, Any?>>()
        val projection =
            arrayOf(
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                CalendarContract.Calendars.ACCOUNT_NAME,
                CalendarContract.Calendars.CALENDAR_COLOR,
            )
        val cursor: Cursor? =
            contentResolver.query(CalendarContract.Calendars.CONTENT_URI, projection, null, null, null)
        cursor?.use {
            while (it.moveToNext()) {
                calendars.add(
                    mapOf(
                        "id" to it.getLong(0).toString(),
                        "name" to (it.getString(1) ?: ""),
                        "accountName" to it.getString(2),
                        "color" to if (it.isNull(3)) null else it.getInt(3),
                    ),
                )
            }
        }
        return calendars
    }

    /// The Instances table (rather than Events) is what expands recurring
    /// events into concrete occurrences inside [start]..[end], so a weekly
    /// meeting shows up on every date it actually falls on.
    private fun queryEvents(
        calendarIds: Set<String>,
        start: Long,
        end: Long,
    ): List<Map<String, Any?>> {
        val events = mutableListOf<Map<String, Any?>>()
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, start)
        ContentUris.appendId(builder, end)
        val projection =
            arrayOf(
                CalendarContract.Instances.EVENT_ID,
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.CALENDAR_ID,
                // The event's own color if it was given one, the calendar's
                // color otherwise - the same rule the real Calendar app
                // uses to color an event.
                CalendarContract.Instances.DISPLAY_COLOR,
            )
        val cursor: Cursor? = contentResolver.query(builder.build(), projection, null, null, null)
        cursor?.use {
            while (it.moveToNext()) {
                val calendarId = it.getLong(5).toString()
                // Filtered here rather than in the query itself - building
                // a safe "IN (...)" selection for an arbitrary-length list
                // buys nothing when the whole window is already a handful
                // of rows.
                if (calendarIds.isNotEmpty() && !calendarIds.contains(calendarId)) continue
                events.add(
                    mapOf(
                        "eventId" to it.getLong(0).toString(),
                        "title" to (it.getString(1) ?: ""),
                        "begin" to it.getLong(2),
                        "end" to it.getLong(3),
                        "allDay" to (it.getInt(4) != 0),
                        "calendarId" to calendarId,
                        "color" to if (it.isNull(6)) null else it.getInt(6),
                    ),
                )
            }
        }
        return events
    }
}
