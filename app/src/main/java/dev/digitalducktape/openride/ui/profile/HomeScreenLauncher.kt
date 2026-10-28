package dev.digitalducktape.openride.ui.profile

import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings

/**
 * The opt-in HOME launcher alias (`.HomeLauncherAlias` in the manifest, PRD P0-8), switched from
 * inside the app (#47, #63).
 *
 * The documented `adb shell pm enable …/.HomeLauncherAlias` can't work: since Android 10 the shell
 * UID may not change component state for an app that isn't `testOnly`, on every bike we know of
 * (Bike+ Android 10, Gen 2 Android 11, `g700` Android 13). An app may always change its own
 * components, so the Profile tab's Device group does it here, and then asks Android to make
 * OpenRide the default home screen. "On" means both: the alias enabled *and* the default, so
 * the Profile row only ever has two states and one button.
 */
object HomeScreenLauncher {
    /** The class name follows the namespace, not the applicationId (`.real` builds included). */
    private const val ALIAS_CLASS = "dev.digitalducktape.openride.HomeLauncherAlias"

    private fun alias(context: Context) = ComponentName(context.packageName, ALIAS_CLASS)

    private fun homeIntent() = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)

    /** Whether the alias is enabled and Android resolves HOME to it. */
    fun isHome(context: Context): Boolean {
        val pm = context.packageManager
        if (pm.getComponentEnabledSetting(alias(context)) != PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
            return false
        }
        val home = pm.resolveActivity(homeIntent(), PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo
        return home?.packageName == context.packageName
    }

    /**
     * Called when the rider comes back from choosing a default home: if they backed out without
     * picking OpenRide, switch the alias off again rather than leave it half on (offered in
     * Android's home chooser, but not the default). Returns [isHome].
     */
    fun settleAfterChoosing(context: Context): Boolean {
        if (!isHome(context)) setEnabled(context, false)
        return isHome(context)
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        context.packageManager.setComponentEnabledSetting(
            alias(context),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
            PackageManager.DONT_KILL_APP,
        )
    }

    /**
     * Whether some other app can be home once OpenRide stops being it. Without one the tablet
     * would boot to Android's FallbackHome and hang there, so the Profile tab won't turn it off.
     */
    fun hasOtherHome(context: Context): Boolean =
        context.packageManager.queryIntentActivities(homeIntent(), 0)
            .any { it.activityInfo.packageName != context.packageName && it.activityInfo.enabled }

    /**
     * What to launch so the rider can make OpenRide the default home: the system's own
     * "set as default home app" prompt when the role is available, else the Home settings page.
     */
    fun chooseDefaultIntent(context: Context): Intent {
        val roles = context.getSystemService(RoleManager::class.java)
        return if (roles != null && roles.isRoleAvailable(RoleManager.ROLE_HOME) && !roles.isRoleHeld(RoleManager.ROLE_HOME)) {
            roles.createRequestRoleIntent(RoleManager.ROLE_HOME)
        } else {
            Intent(Settings.ACTION_HOME_SETTINGS)
        }
    }
}
