package com.example.hanneslauncher

import android.app.Notification
import android.service.notification.NotificationListenerService

/// Android only hands out the active media sessions - and the list of
/// standing notifications - to an app it has accepted as a notification
/// listener, and the only way to become one is to declare a service like
/// this.
///
/// It still does nothing with the notifications as they arrive: it keeps no
/// text, no sender and nothing on disk. Its whole job is to exist, so that
/// MediaSessionManager.getActiveSessions() in MainActivity is allowed to
/// answer at all, and so [countsByPackage] can say how many notifications a
/// package currently has standing - the number behind the badge on a pinned
/// app.
class MediaNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        connected = this
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (connected === this) connected = null
    }

    companion object {
        // Set while Android has this service bound. getActiveNotifications()
        // only answers on that bound instance, so MainActivity - which is a
        // different object entirely - needs a way to reach it.
        private var connected: MediaNotificationListener? = null

        val isConnected: Boolean
            get() = connected != null

        /// How many notifications each package currently has standing.
        /// Packages with none are simply absent.
        fun countsByPackage(): Map<String, Int> {
            val service = connected ?: return emptyMap()
            val active = try {
                service.activeNotifications
            } catch (_: Exception) {
                // Thrown rather than returning empty when the binding has
                // gone away between the check above and here.
                null
            } ?: return emptyMap()

            // Kept apart rather than added into one map, because a group
            // summary only stands in for children that are actually there -
            // see the fold below.
            val children = mutableMapOf<String, Int>()
            val summaries = mutableMapOf<String, Int>()
            for (notification in active) {
                val details = notification.notification ?: continue
                // Anything the user cannot swipe away is a standing status
                // line, not news: a music player, a download, a VPN. Counting
                // those would leave a badge sitting on an app forever.
                // isClearable already covers the ongoing flag.
                if (!notification.isClearable) continue
                // Notification.number is what the app itself puts in a badge
                // ("3 new messages" in one chat). Not every app sets it, so a
                // notification without one counts as the single item it is.
                val number = if (details.number > 0) details.number else 1
                val into =
                    if (details.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
                        summaries
                    } else {
                        children
                    }
                into[notification.packageName] =
                    (into[notification.packageName] ?: 0) + number
            }

            // Messengers post one notification per chat plus a summary
            // holding them together, so counting the summary as well would
            // read every single message as two - which is why it is dropped
            // wherever there are children to drop it in favour of.
            //
            // But a group of one is still a group: with a single chat
            // waiting, an app can post nothing but the summary. Dropping
            // that one unconditionally left the package at zero and the
            // pinned icon bare while a message was plainly waiting, so a
            // package with no children at all counts its summaries instead.
            for ((packageName, count) in summaries) {
                if (!children.containsKey(packageName)) children[packageName] = count
            }
            return children
        }

        /// Everything currently waiting, newest first: which app, what it
        /// says, and the key needed to swipe it away again.
        ///
        /// A deliberate step past [countsByPackage], and worth being clear
        /// about. The badge only ever needed a number, and the app has said
        /// all along that a number is all it reads. This reads the title and
        /// the text too - but only to draw them, in this process, for the one
        /// person holding the phone, for as long as the panel is open.
        /// Nothing is written anywhere, nothing is kept once the panel shuts,
        /// and nothing leaves the device. The block that shows it is off
        /// until switched on.
        fun activeNotifications(): List<Map<String, Any?>> {
            val service = connected ?: return emptyList()
            val active = try {
                service.activeNotifications
            } catch (_: Exception) {
                null
            } ?: return emptyList()

            val rows = mutableListOf<Map<String, Any?>>()
            for (notification in active) {
                val details = notification.notification ?: continue
                // Same rule as the badge: anything that cannot be swiped away
                // is a standing status line - a player, a download, a VPN -
                // not something waiting to be read.
                if (!notification.isClearable) continue
                // The summary is the wrapper around the ones below it. Shown
                // as well, it would print "3 new messages" above the three
                // messages themselves.
                if (details.flags and Notification.FLAG_GROUP_SUMMARY != 0) continue

                val extras = details.extras
                val title = extras?.getCharSequence(Notification.EXTRA_TITLE)
                val text = extras?.getCharSequence(Notification.EXTRA_TEXT)
                    ?: extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)
                rows.add(
                    mapOf(
                        "key" to notification.key,
                        "package" to notification.packageName,
                        "title" to title?.toString(),
                        "text" to text?.toString(),
                        "postedAt" to notification.postTime,
                    )
                )
            }
            rows.sortByDescending { it["postedAt"] as Long }
            return rows
        }

        /// Swipes one away, exactly as pulling it off the system shade would.
        fun dismiss(key: String): Boolean {
            val service = connected ?: return false
            return try {
                service.cancelNotification(key)
                true
            } catch (_: Exception) {
                false
            }
        }

        /// The intent the notification itself carries - what tapping it in
        /// the system shade would fire. Returned rather than fired here so
        /// the caller decides, and null when the notification has none,
        /// which is ordinary: plenty are purely informational.
        fun contentIntent(key: String): android.app.PendingIntent? {
            val service = connected ?: return null
            val active = try {
                service.activeNotifications
            } catch (_: Exception) {
                null
            } ?: return null
            for (notification in active) {
                if (notification.key == key) {
                    return notification.notification?.contentIntent
                }
            }
            return null
        }
    }
}
