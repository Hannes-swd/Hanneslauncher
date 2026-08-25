package com.example.hanneslauncher

import android.service.notification.NotificationListenerService

/// Android only hands out the active media sessions to an app it has
/// accepted as a notification listener, and the only way to become one is to
/// declare a service like this. It deliberately does nothing with the
/// notifications themselves - its whole job is to exist, so that
/// MediaSessionManager.getActiveSessions() in MainActivity is allowed to
/// answer at all.
class MediaNotificationListener : NotificationListenerService()
