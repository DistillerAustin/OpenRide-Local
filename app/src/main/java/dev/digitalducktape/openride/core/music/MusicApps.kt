package dev.digitalducktape.openride.core.music

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.service.media.MediaBrowserService

/** A music app on the tablet: its package and the name its launcher icon shows. */
data class MusicApp(val packageName: String, val label: String)

/**
 * Finding and opening the rider's music apps, for the music app picker and the player's button
 * that opens the rider's chosen app (nothing playing). A music app is one that serves its
 * library to Android Auto and the like, through a [MediaBrowserService]: Apple Music, Spotify,
 * Pandora, SiriusXM and most others do.
 */
object MusicApps {
    /** By name; [exclude] (OpenRide), nameless ones and duplicates left out. */
    fun order(apps: List<MusicApp>, exclude: String): List<MusicApp> = apps
        .filter { it.packageName != exclude && it.label.isNotBlank() }
        .distinctBy { it.packageName }
        .sortedBy { it.label.lowercase() }

    /** The tablet's music apps that can be opened, in [order]. */
    fun installed(context: Context): List<MusicApp> {
        val pm = context.packageManager
        val apps = pm.queryIntentServices(Intent(MediaBrowserService.SERVICE_INTERFACE), 0)
            .map { it.serviceInfo.packageName }
            .filter { pm.getLaunchIntentForPackage(it) != null }
            .mapNotNull { find(context, it) }
        return order(apps, exclude = context.packageName)
    }

    /** [packageName] as a [MusicApp], or null when it's no longer installed. */
    fun find(context: Context, packageName: String): MusicApp? = try {
        val pm = context.packageManager
        MusicApp(packageName, pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString())
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    /**
     * Brings [packageName] forward the way a launcher would (its existing task, so music already
     * playing isn't restarted). A ride keeps recording while the music app is in front. Returns
     * false when it can't be opened, e.g. it was uninstalled.
     */
    fun open(context: Context, packageName: String): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(packageName) ?: return false
        return try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }
}
