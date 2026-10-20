package dev.digitalducktape.openride.games.session

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Where the Compose app goes when the rider leaves games. */
sealed interface VisitDestination {
    data class RideSummary(val rideId: Long) : VisitDestination
    data object EditProfile : VisitDestination
}

/**
 * The app's next screen after a hub visit, consumed once (the app's NavHost collects
 * [pending], navigates, then calls [consume]). App-scoped, so it survives the trip between the
 * games task and the app's.
 */
class VisitNavigator {
    private val _pending = MutableStateFlow<VisitDestination?>(null)
    val pending: StateFlow<VisitDestination?> = _pending.asStateFlow()

    /**
     * A visit ended with `visit_ended.next` [next]: `edit_profile` (the FTP nudge) opens the
     * profile editor, `app` the saved ride's summary, and `hub` (the idle guard: the rider is
     * still in games) nothing yet.
     */
    fun visitEnded(rideId: Long?, next: String) {
        when {
            next == "edit_profile" -> _pending.value = VisitDestination.EditProfile
            next == GameVisitManager.NEXT_HUB -> Unit
            rideId != null -> _pending.value = VisitDestination.RideSummary(rideId)
        }
    }

    /** The app has shown [destination]. A newer one queued meanwhile stays. */
    fun consume(destination: VisitDestination) {
        _pending.compareAndSet(destination, null)
    }
}
