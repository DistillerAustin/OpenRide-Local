package dev.digitalducktape.openride.ui.home

import dev.digitalducktape.openride.core.data.Profile
import dev.digitalducktape.openride.core.ride.RideGoal

/**
 * Everything the Home tab renders, as one value (docs/MAIN_UI_REFRESH.md §2: one UiState per
 * screen). The update banner is not here: it is app-wide state that `MainScaffold` passes in.
 *
 * @param profile the active rider, or `null` while none is selected or its row hasn't loaded.
 * @param goal the pre-ride goal (PRD P1-3).
 */
data class HomeUiState(
    val profile: Profile? = null,
    val goal: RideGoal = RideGoal.None,
) {
    /** The greeting's name; "Rider" until a profile is loaded. */
    val riderName: String get() = profile?.name ?: "Rider"

    /** "No goal set", "Goal: 30 min", "Goal: 300 kJ". */
    val goalLabel: String get() = goalSummaryLabel(goal)

    /** The goal button's text. */
    val goalActionLabel: String get() = if (goal == RideGoal.None) "Set goal" else "Change goal"
}
