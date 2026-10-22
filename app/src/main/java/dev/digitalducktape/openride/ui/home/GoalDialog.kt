package dev.digitalducktape.openride.ui.home

import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import dev.digitalducktape.openride.core.ride.RideGoal
import dev.digitalducktape.openride.ui.designsystem.ComponentPreview
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.component.OrFormDialog
import dev.digitalducktape.openride.ui.designsystem.component.OrRadioRow
import dev.digitalducktape.openride.ui.designsystem.component.OrTextField
import dev.digitalducktape.openride.ui.theme.OpenRideTheme

/** The three kinds of pre-ride goal the dialog offers. */
internal enum class GoalKind { None, Duration, Output }

/** The goal form's pure logic (plain-JUnit testable). */
internal object GoalForm {
    fun kindOf(goal: RideGoal): GoalKind = when (goal) {
        RideGoal.None -> GoalKind.None
        is RideGoal.Duration -> GoalKind.Duration
        is RideGoal.Output -> GoalKind.Output
    }

    /** The minutes field's starting text: the current time goal, else blank. */
    fun initialMinutes(goal: RideGoal): String = if (goal is RideGoal.Duration) (goal.targetSec / 60).toString() else ""

    /** The kJ field's starting text: the current output goal, else blank. */
    fun initialKj(goal: RideGoal): String = if (goal is RideGoal.Output) goal.targetKj.toString() else ""

    /**
     * The goal to save. Invalid or blank input on the selected kind falls back to
     * [RideGoal.None] rather than blocking the dialog: a wrong goal number only affects an
     * on-screen progress bar, so a simple picker beats form validation here.
     */
    fun toGoal(kind: GoalKind, minutesInput: String, kjInput: String): RideGoal = when (kind) {
        GoalKind.None -> RideGoal.None
        GoalKind.Duration -> minutesInput.trim().toIntOrNull()?.takeIf { it > 0 }?.let { RideGoal.Duration(it * 60) } ?: RideGoal.None
        GoalKind.Output -> kjInput.trim().toDoubleOrNull()?.takeIf { it > 0.0 }?.let { RideGoal.Output(it) } ?: RideGoal.None
    }
}

/**
 * Pre-ride goal picker (PRD P1-3): no goal, a time target (minutes), or an output target (kJ),
 * as radio rows with the number field under the chosen one; Cancel and Save.
 */
@Composable
fun GoalDialog(
    currentGoal: RideGoal,
    onDismiss: () -> Unit,
    onSave: (RideGoal) -> Unit,
    modifier: Modifier = Modifier,
) {
    var kind by remember { mutableStateOf(GoalForm.kindOf(currentGoal)) }
    var minutesInput by remember { mutableStateOf(GoalForm.initialMinutes(currentGoal)) }
    var kjInput by remember { mutableStateOf(GoalForm.initialKj(currentGoal)) }
    val fieldPadding = Modifier.padding(start = OrSpacing.xxl, top = OrSpacing.xs, bottom = OrSpacing.sm)

    OrFormDialog(
        title = "Ride goal",
        confirmText = "Save",
        onConfirm = { onSave(GoalForm.toGoal(kind, minutesInput, kjInput)) },
        onDismiss = onDismiss,
        modifier = modifier,
    ) {
        OrRadioRow(label = "No goal", selected = kind == GoalKind.None, onClick = { kind = GoalKind.None })
        OrRadioRow(label = "Time target", selected = kind == GoalKind.Duration, onClick = { kind = GoalKind.Duration })
        if (kind == GoalKind.Duration) {
            OrTextField(
                value = minutesInput,
                onValueChange = { minutesInput = it },
                label = "Minutes",
                keyboardType = KeyboardType.Number,
                modifier = fieldPadding,
            )
        }
        OrRadioRow(label = "Output target", selected = kind == GoalKind.Output, onClick = { kind = GoalKind.Output })
        if (kind == GoalKind.Output) {
            OrTextField(
                value = kjInput,
                onValueChange = { kjInput = it },
                label = "Target kJ",
                keyboardType = KeyboardType.Decimal,
                modifier = fieldPadding,
            )
        }
    }
}

/** Compact label for the current goal, used on the Home screen (PRD P1-3). */
fun goalSummaryLabel(goal: RideGoal): String = when (goal) {
    RideGoal.None -> "No goal set"
    is RideGoal.Duration -> "Goal: ${goal.targetSec / 60} min"
    is RideGoal.Output -> "Goal: %.0f kJ".format(goal.targetKj)
}

@ComponentPreview
@Composable
private fun GoalDialogPreview() {
    OpenRideTheme {
        GoalDialog(currentGoal = RideGoal.Duration(30 * 60), onDismiss = {}, onSave = {})
    }
}
