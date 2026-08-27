package com.example.hanneslauncher

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.role.RoleManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
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
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.ConnectivityManager
import android.net.Uri
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.CalendarContract
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val gestureChannelName = "hanneslauncher/system_gestures"
    private val calendarChannelName = "hanneslauncher/calendar"
    private val systemAppsChannelName = "hanneslauncher/system_apps"
    private val backupChannelName = "hanneslauncher/backup"
    private val deviceStatsChannelName = "hanneslauncher/device_stats"
    private val appInfoChannelName = "hanneslauncher/app_info"
    private val browsersChannelName = "hanneslauncher/browsers"
    private val offlineModeChannelName = "hanneslauncher/offline_mode"
    private val mediaChannelName = "hanneslauncher/media"
    private val calendarPermissionRequestCode = 4201
    private val importFileRequestCode = 4202
    private val stepsPermissionRequestCode = 4203
    private val homeRoleRequestCode = 4204

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
                    "defaultLauncher" -> result.success(defaultLauncher())
                    "chooseDefaultLauncher" ->
                        result.success(chooseDefaultLauncher())
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

        // The version this APK was actually built as, read from the installed
        // package itself rather than from a constant in the Dart code - a
        // constant is one more thing to remember to bump on a release, and
        // forgetting it would mean the update check compares against the
        // wrong number and either never or always reports an update.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appInfoChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> result.success(installedVersion())
                    "canInstallApks" -> result.success(canInstallApks())
                    "requestInstallPermission" -> result.success(requestInstallPermission())
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        result.success(if (path == null) false else installApk(path))
                    }
                    else -> result.notImplemented()
                }
            }

        // Lets a web app be opened in one browser in particular instead of
        // whatever Android's default is. url_launcher can only ask for "a
        // browser", so both listing them and aiming at one happen here.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, browsersChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "list" -> result.success(installedBrowsers())
                    "open" -> {
                        val url = call.argument<String>("url")
                        val browserPackage = call.argument<String>("package")
                        result.success(
                            if (url == null || browserPackage == null) {
                                false
                            } else {
                                openInBrowser(url, browserPackage)
                            },
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        // The offline mode is meant to be looked at from across the room
        // while the phone charges, so the screen must not turn itself off
        // for as long as it is open. A window flag rather than a wakelock:
        // it is tied to this window, so it can't outlive the app and drain
        // the battery if something goes wrong on the way out.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, offlineModeChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Android's own battery saver can only be switched by a
                    // system app (it is behind WRITE_SECURE_SETTINGS), so
                    // this opens the screen where the user does it instead
                    // of pretending the app could.
                    "openBatterySaverSettings" -> result.success(
                        openSettings(Settings.ACTION_BATTERY_SAVER_SETTINGS),
                    )
                    "keepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        runOnUiThread {
                            if (on) {
                                window.addFlags(
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                                )
                            } else {
                                window.clearFlags(
                                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                                )
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // What's playing right now, read from Android's own media sessions -
        // the same thing the lock screen shows. That covers every player at
        // once (Spotify, YouTube Music, a podcast app) with no account, no
        // login and no subscription, which no single service's API can.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasNotificationAccess())
                    "requestPermission" -> result.success(requestNotificationAccess())
                    "current" -> result.success(currentMedia())
                    "next" -> result.success(sendMediaCommand(next = true))
                    "previous" -> result.success(sendMediaCommand(next = false))
                    else -> result.notImplemented()
                }
            }
    }

    // Started without resolveActivity() on purpose, like the other settings
    // screens here: one isn't reliably visible to a package visibility
    // query, and a null answer would leave no way in at all.
    private fun openSettings(action: String): Boolean {
        return try {
            startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) {
            false
        }
    }

    // Reading the media sessions needs this app to be an enabled
    // notification listener, which is not a runtime permission - there is no
    // prompt for it, only a system settings screen the user has to walk
    // through themselves. Android names the enabled ones in one flat
    // secure setting, so that is what gets searched for this package.
    private fun hasNotificationAccess(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':').any {
            ComponentName.unflattenFromString(it)?.packageName == packageName
        }
    }

    // Opens that screen.
    private fun requestNotificationAccess(): Boolean =
        openSettings(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)

    // The session worth showing: the one actually playing, or else the first
    // one there is, so a track paused mid-listen still names itself instead
    // of the screen going blank. Null when nothing is playing at all, or
    // when the permission hasn't been granted - both mean "show nothing",
    // and the Dart side doesn't need to tell them apart.
    private fun activeMediaController(): MediaController? {
        if (!hasNotificationAccess()) return null
        return try {
            val manager = getSystemService(MediaSessionManager::class.java)
                ?: return null
            val listener = ComponentName(this, MediaNotificationListener::class.java)
            val sessions = manager.getActiveSessions(listener)
            sessions.firstOrNull {
                it.playbackState?.state == PlaybackState.STATE_PLAYING
            } ?: sessions.firstOrNull()
        } catch (_: Exception) {
            // getActiveSessions throws rather than returning empty when the
            // listener isn't accepted (yet) - just as much a "nothing to
            // show" as an empty list.
            null
        }
    }

    private fun currentMedia(): Map<String, Any?>? {
        val controller = activeMediaController() ?: return null
        val metadata = controller.metadata ?: return null
        val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
        val artist =
            metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: metadata.getString(
                    MediaMetadata.METADATA_KEY_ALBUM_ARTIST,
                )
        // A session with no title at all is a player that has started but
        // has nothing loaded - there would be nothing to draw.
        if (title.isNullOrBlank()) return null
        return mapOf(
            "title" to title,
            "artist" to artist,
            "playing" to
                (controller.playbackState?.state == PlaybackState.STATE_PLAYING),
        )
    }

    private fun sendMediaCommand(next: Boolean): Boolean {
        val controller = activeMediaController() ?: return false
        return try {
            if (next) {
                controller.transportControls.skipToNext()
            } else {
                controller.transportControls.skipToPrevious()
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    // Which app the home button currently opens, so the settings can say
    // whether this launcher is it. With no default set at all Android answers
    // with its own chooser (package "android"), which is a "no" with no name
    // to show.
    private fun defaultLauncher(): Map<String, Any?> {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved =
            packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
        val resolvedPackage = resolved?.activityInfo?.packageName
        if (resolvedPackage == null || resolvedPackage == "android") {
            return mapOf("isThisApp" to false, "package" to null, "name" to null)
        }
        return mapOf(
            "isThisApp" to (resolvedPackage == packageName),
            "package" to resolvedPackage,
            "name" to resolved.loadLabel(packageManager).toString(),
        )
    }

    // Three ways in, best first, because no single one works everywhere:
    //
    // From Android 10 the system can ask "make this your home app?" right
    // here, which is one tap and needs no hunting through settings.
    //
    // Where that isn't offered (older Android, or a ROM that dropped the
    // role) the system's own "Default home app" screen is opened instead,
    // then the wider default-apps list. Started without resolveActivity()
    // on purpose - a settings screen isn't always visible to a package
    // visibility query, and a null answer there would leave no way in at
    // all. Returns false only if none of them opened, which is what the
    // written instructions on the screen are there for.
    private fun chooseDefaultLauncher(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager != null &&
                roleManager.isRoleAvailable(RoleManager.ROLE_HOME) &&
                !roleManager.isRoleHeld(RoleManager.ROLE_HOME)
            ) {
                try {
                    // For a result, not because the answer is read (the
                    // screen re-checks when it comes back anyway) but
                    // because that is how the role dialog is documented to
                    // be started - launched as a plain activity it can close
                    // again without ever showing.
                    startActivityForResult(
                        roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME),
                        homeRoleRequestCode,
                    )
                    return true
                } catch (e: Exception) {
                    // Falls through to the settings screens below.
                }
            }
        }
        if (startOrFalse(Intent(Settings.ACTION_HOME_SETTINGS))) return true
        return startOrFalse(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
    }

    private fun startOrFalse(intent: Intent): Boolean {
        return try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
    }

    // The apps that can show any web page - the same set Android's own
    // "default browser" screen offers, and queried the same way it does.
    //
    // Two details decide whether this returns all of them or just one:
    //
    // MATCH_ALL, because without it the query honours the user's default
    // browser and answers with that single app - every other installed
    // browser silently disappears from the list.
    //
    // A host under the reserved ".invalid" domain, because an app that only
    // claims links of its own (YouTube, a bank app, ...) filters on its own
    // host and won't answer for one that cannot exist, while a real browser
    // takes any host. Leaving the host off entirely would instead drop the
    // browsers whose filter is written as host="*".
    private fun installedBrowsers(): List<Map<String, Any?>> {
        val probe =
            Intent(Intent.ACTION_VIEW, Uri.parse("https://browser.invalid"))
                .addCategory(Intent.CATEGORY_BROWSABLE)
        return packageManager.queryIntentActivities(probe, PackageManager.MATCH_ALL)
            .map {
                mapOf<String, Any?>(
                    "package" to it.activityInfo.packageName,
                    "name" to it.loadLabel(packageManager).toString(),
                )
            }
            // A browser registering several activities would otherwise be
            // listed once per activity.
            .distinctBy { it["package"] }
            .sortedBy { (it["name"] as String).lowercase() }
    }

    // False rather than an exception when the chosen browser was uninstalled
    // or disabled since it was picked - the Dart side then falls back to the
    // default browser, so the page still opens.
    private fun openInBrowser(url: String, browserPackage: String): Boolean {
        return try {
            startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                    .setPackage(browserPackage)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    // Not a runtime prompt: "install unknown apps" is a per-app switch in
    // the system settings, and sending the user there is the only way to get
    // it turned on. Started without resolveActivity() on purpose - the
    // settings screen isn't always visible to a package-visibility query,
    // and a null result there would leave the user with no way in at all.
    private fun requestInstallPermission(): Boolean {
        return try {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (e: Exception) {
            // Some vendor ROMs don't carry the per-app screen: the general
            // one at least gets the user to the right list.
            startIfResolvable(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES))
        }
    }

    private fun canInstallApks(): Boolean {
        // The permission only exists from Android 8 on; below that any app
        // could hand a file to the installer.
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    // Hands a downloaded APK to Android's own installer. The file lives in
    // this app's cache dir, so the installer - a different app - can only
    // read it through the FileProvider plus a one-off read grant.
    private fun installApk(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun installedVersion(): Map<String, Any?> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val code =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        return mapOf(
            "versionName" to (info.versionName ?: ""),
            "versionCode" to code,
        )
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
            val file = File(backupDir, "hanneslauncher_backup.json")
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
