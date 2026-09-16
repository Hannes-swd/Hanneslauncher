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

            val counts = mutableMapOf<String, Int>()
            for (notification in active) {
                val details = notification.notification ?: continue
                // Anything the user cannot swipe away is a standing status
                // line, not news: a music player, a download, a VPN. Counting
                // those would leave a badge sitting on an app forever.
                if (notification.isOngoing || !notification.isClearable) continue
                // Messengers post one notification per chat plus a summary
                // holding them together. Counting the summary too would make
                // every single message read as two.
                if (details.flags and Notification.FLAG_GROUP_SUMMARY != 0) continue
                // Notification.number is what the app itself puts in a badge
                // ("3 new messages" in one chat). Not every app sets it, so a
                // notification without one counts as the single item it is.
                val number = if (details.number > 0) details.number else 1
                counts[notification.packageName] =
                    (counts[notification.packageName] ?: 0) + number
            }
            return counts
        }
    }
}
