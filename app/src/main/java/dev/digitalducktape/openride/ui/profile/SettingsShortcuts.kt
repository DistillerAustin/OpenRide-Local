package dev.digitalducktape.openride.ui.profile

import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Quick access to stock Android settings from within the app (PRD user story: "I want to
 * still reach stock Android settings (WiFi, volume) from within the app so that basic
 * device maintenance doesn't require re-running OpenPelo"; PRD P1-5). Relevant once
 * MainActivity is the tablet's launcher (T12's opt-in HOME alias) and the stock Settings
 * app icon may not be easily reachable otherwise. The Profile tab's Device group calls this.
 *
 * Launches a stock Android settings screen by [action] (e.g. [Settings.ACTION_WIFI_SETTINGS]).
 */
fun launchSettings(context: Context, action: String) {
    context.startActivity(Intent(action))
}
