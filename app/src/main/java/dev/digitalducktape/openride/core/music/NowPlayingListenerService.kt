package dev.digitalducktape.openride.core.music

import android.service.notification.NotificationListenerService

/**
 * Exists only so the rider can grant "Notification access", which is the permission Android
 * ties to reading other apps' media sessions ([NowPlayingMonitor]). It deliberately overrides
 * nothing: OpenRide never reads, stores or reacts to a notification.
 */
class NowPlayingListenerService : NotificationListenerService()
