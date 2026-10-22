class_name HubCalibration
extends RefCounted
## Calibrating from the hub (spec §6, plan phase E): what a tap on the camera chip does, and
## when a calibration the hub started has ended. The rider calibrates once per visit; every
## camera game after that reuses it (Kotlin's TrackerLink keeps the centre for the visit).
##
## An enum FSM (state-machine skill: three states, no per-state processing):
##   IDLE ──tap──► (camera off: explain) | (denied: explain) | ASKING (permission) | RUNNING
##   ASKING ──hub_state: granted──► RUNNING;  ──hub_state: still ask, or denied──► IDLE (refused)
##   RUNNING ──hub_state with the tracker no longer calibrating──► IDLE (done | failed)
##   RUNNING ──Cancel / back──► IDLE
## Kotlin sends hub_state when a hub calibration ends (TrackerLink.onHubCalibrationEnded); the
## tracker state (bridge field 9) tells an end from a hub_state sent mid-run.

enum Step { IDLE, ASKING, RUNNING }

const MODE := "lean_x"  ## spec §6: depth is asked on demand by a lean_2d game
const DEBOUNCE_MSEC := 1000  ## stray taps on the bike (the in-game rule)
## A hub_state this soon after the start is from before it (Kotlin hasn't begun calibrating).
const MIN_RUN_MSEC := 300

var step := Step.IDLE
## The running calibration is a full one (Recalibrate): the visit was calibrated already.
var full := false
var started_msec := -1
var _last_tap_msec := -DEBOUNCE_MSEC


## A tap on the camera chip (or the hub's Calibrate). Returns what the hub should do:
## "ignore" (running, or a stray second tap), "camera_off" (offer to turn camera games on),
## "denied" (explain Android's settings), "ask" (request the permission; calibrates once
## granted) or "calibrate" (hub_calibrate(MODE, full) and show the overlay).
func tap(state: Dictionary, now_msec: int) -> String:
	if step != Step.IDLE or now_msec - _last_tap_msec < DEBOUNCE_MSEC:
		return "ignore"
	_last_tap_msec = now_msec
	if not bool(state.settings.get("camera_games", true)):
		return "camera_off"
	match str(state.camera.get("permission", "granted")):
		"denied":
			return "denied"
		"ask":
			step = Step.ASKING
			return "ask"
	return _begin(state, now_msec)


## A hub_state arrived: "" (nothing to do), "calibrate" (the permission was just granted),
## "refused" (it wasn't), "done" or "failed" (the hub's calibration ended).
func on_state(state: Dictionary, tracker_state: int, now_msec: int) -> String:
	match step:
		Step.ASKING:
			var permission := str(state.camera.get("permission", "granted"))
			if permission == "granted" and bool(state.settings.get("camera_games", true)):
				return _begin(state, now_msec)
			step = Step.IDLE
			return "refused"
		Step.RUNNING:
			if now_msec - started_msec < MIN_RUN_MSEC or tracker_state == InputBus.TRACKER_CALIBRATING:
				return ""
			step = Step.IDLE
			var ok := bool(state.camera.get("available", true)) and not str(state.camera.get("calibrated", "")).is_empty()
			return "done" if ok else "failed"
	return ""


func cancel() -> void:
	step = Step.IDLE


func running() -> bool:
	return step == Step.RUNNING


func _begin(state: Dictionary, now_msec: int) -> String:
	step = Step.RUNNING
	started_msec = now_msec
	full = not str(state.camera.get("calibrated", "")).is_empty()
	return "calibrate"
