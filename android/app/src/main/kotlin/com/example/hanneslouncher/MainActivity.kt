package com.example.hanneslouncher

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.database.Cursor
import android.graphics.Rect
import android.os.Build
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val gestureChannelName = "hanneslouncher/system_gestures"
    private val calendarChannelName = "hanneslouncher/calendar"
    private val calendarPermissionRequestCode = 4201

    // A plugin (device_calendar) returning every field as null on some
    // Android versions is what this replaces - reading Android's own
    // CalendarContract directly, with no library in between to disagree
    // with the platform about column types.
    private var pendingPermissionResult: MethodChannel.Result? = null

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
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == calendarPermissionRequestCode) {
            val granted =
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
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
