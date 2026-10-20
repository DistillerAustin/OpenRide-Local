extends Node
## Desktop stand-in for the Kotlin session (docs/GAMES.md, "Desktop simulation"). Plays a local
## plan through Session with the same timeline as the app (GameSessionManager.kt):
##   session_started → per segment: segment_started → intro card (intro_sec) → gameplay →
##   segment_ending when the timer runs out (1.5 × duration for end_mode "game") → the game's
##   segment_finished, or a zero result after 5 s. A timed plan then finishes by itself; an
##   open-ended one waits for request_end.
## Payloads go through a JSON round trip so games see exactly the types the bridge delivers
## (every number a float).
##
## It also stands in for the head tracker and its session side (TrackerLink.kt, docs/GAMES.md
## "Head tracker"): `tracker_state()` follows `set_tracker_mode`; a session's first camera mode
## starts a scripted calibration by itself (centre-only once this process has "same-day"
## extremes covering the mode, otherwise centre, left, right, and in/back for lean_2d), and
## `request_calibration` runs every step. Progress arrives as calibration_progress.
##
## The Games hub (v1.1) is played by its child `LocalHub`: the project's main scene (the hub)
## starts a desktop visit instead of a Just Ride, and the hub's calls go there. A plan of a
## visit keeps the visit's calibration (its `calibrated`), as TrackerLink does on the bike.

const INTRO_SEC := 10
const GRACE_SEC := 5.0
const DEFAULT_GAME_ID := "demo"
## The desktop's stand-in profile name (`session_started`'s `rider_name`), for plans that don't
## carry one.
const RIDER_NAME := "Alex"
## Simulated calibration: seconds per step.
const CALIBRATION_STEPS := {"centre": 3.0, "left": 2.0, "right": 2.0, "in": 2.0, "back": 2.0}
const CALIBRATION_REPORT_SEC := 0.1
const LocalHub := preload("res://autoload/LocalHub.gd")
const DEFAULT_AUDIO := {"music": true, "music_volume": 0.8, "sfx_volume": 1.0}

var _session: Node
var _plan: Dictionary = {}
var _segment: Dictionary = {}
var _phase := ""  # "", "intro", "playing", "ending", "awaiting_end", "finished"
var _intro_left := 0.0
var _played := 0.0
var _grace_left := 0.0
var _elapsed := 0.0
var _paused := false  ## the combined pause, as signalled
var _rider_paused := false
var _end_requested := false
var _results: Array = []
var _default_game_id := ""
var _tracker_mode := "off"
var _calibration_steps: Array = []  # steps still to run; empty when not calibrating
var _calibration_count := 0
var _calibration_step_left := 0.0
var _calibration_report_left := 0.0
var _session_calibrated := false  # this session's centre is taken (TrackerLink's resetSession)
var _extremes := {}  # modes with "same-day" extremes: lean_x, lean_2d (kept across sessions)
var _calibration_mode := ""
## Calibrations started since launch, automatic or requested (for tests: one per session start).
var calibrations_started := 0
## The hub's v1.1 calls, recorded as [method, args…] (for tests), then played by `hub`.
var hub_calls: Array = []
## The desktop's stand-in for Kotlin's visit (GameVisitManager).
var hub: Node


func _init(session: Node) -> void:
	_session = session
	process_mode = Node.PROCESS_MODE_ALWAYS
	hub = LocalHub.new(self, session)
	add_child(hub)


## A Just Ride of the open game: a scene run on its own (F6) may declare `game_id`, as every
## `Game` does. Later restarts (request_exit) replay the same game.
func default_plan() -> Dictionary:
	var game_id := _default_game_id
	if game_id.is_empty():
		game_id = DEFAULT_GAME_ID
		var scene := get_tree().current_scene
		if scene and scene.get("game_id") is String and not scene.get("game_id").is_empty():
			game_id = scene.get("game_id")
		_default_game_id = game_id
	return {
		"kind": "just_ride",
		"plan_id": "just-ride:%s" % game_id,
		"difficulty": "standard",
		"total_sec": -1,
		"segments": [{"game_id": game_id, "role": "free", "duration_sec": -1}],
	}


## Starts the default plan when a game scene runs on its own (F6), or a hub visit when the
## project runs (its main scene is the hub). Under a `-s` script (the headless checks and
## GdUnit4) nothing starts until the script calls `start()` or `hub.begin_visit()`.
func autostart() -> void:
	var scene := get_tree().current_scene
	if not _plan.is_empty() or scene == null:
		return
	if scene.scene_file_path == SessionDirector.IDLE_SCENE:
		hub.begin_visit()
	else:
		start()


## As Kotlin's request_exit: in a visit's hub it exits the hub; during a visit's plan it ends
## the plan (v1's early exit); outside a visit it restarts the local plan.
func request_exit() -> void:
	if hub.is_live():
		if _phase in ["", "finished"]:
			hub.exit_hub("app")
		else:
			request_end()
	else:
		start()


func start(plan: Dictionary = {}) -> void:
	_plan = plan if not plan.is_empty() else default_plan()
	_segment = {}
	_phase = ""
	_elapsed = 0.0
	_paused = false
	_rider_paused = false
	_end_requested = false
	_results = []
	_calibration_steps = []
	# A visit's later plan keeps the visit's centre (TrackerLink resets once per visit).
	_session_calibrated = not str(_plan.get("calibrated", "")).is_empty()
	if _session_calibrated:
		_calibration_mode = str(_plan.calibrated)
	var sent := _plan.duplicate()
	if not sent.has("rider_name"):
		sent["rider_name"] = RIDER_NAME
	_session._on_session_started(_wire(sent))
	_start_segment(0)


# --- The Games hub (v1.1): recorded, then played by LocalHub ---

func start_plan(request: Dictionary) -> void:
	hub_calls.append(["start_plan", request])
	hub.start_plan(request)


func update_setting(key: String, value: Variant) -> void:
	hub_calls.append(["update_setting", key, value])
	hub.update_setting(key, value)


func hub_calibrate(mode: String, full: bool) -> void:
	hub_calls.append(["hub_calibrate", mode, full])
	hub.hub_calibrate(mode, full)


func cancel_calibration() -> void:
	hub_calls.append(["cancel_calibration"])
	hub.cancel_calibration()


func request_camera_permission() -> void:
	hub_calls.append(["request_camera_permission"])
	hub.request_camera_permission()


func exit_hub(next: String) -> void:
	hub_calls.append(["exit_hub", next])
	hub.exit_hub(next)


func hub_activity() -> void:
	hub_calls.append(["hub_activity"])
	hub.hub_activity()


## The calibration this process's session holds now: "" (none), "lean_x" or "lean_2d".
func calibrated_mode() -> String:
	return _calibration_mode if _session_calibrated else ""


func time_left() -> float:
	if _phase in ["", "awaiting_end", "finished"]:
		return -1.0
	var duration: float = _segment.get("duration_sec", -1)
	return -1.0 if duration < 0 else maxf(0.0, duration - _played)


func segment_finished(result: Dictionary) -> void:
	if _phase not in ["intro", "playing", "ending"]:
		return
	_results.append(result if result.has("game_id") else _zero_result())
	_advance()


func request_pause() -> void:
	if _rider_paused or _phase in ["", "finished"]:
		return
	_rider_paused = true
	_refresh_paused()


func request_resume() -> void:
	if not _rider_paused:
		return
	_rider_paused = false
	_refresh_paused()


## As GameSessionManager.refreshPaused: the rider's pause or a running calibration pauses the
## session; signalled only when the combined state changes.
func _refresh_paused() -> void:
	var now := _rider_paused or (is_calibrating() and _phase in ["intro", "playing", "ending"])
	if now == _paused:
		return
	_paused = now
	if now:
		_session._on_session_paused()
	else:
		_session._on_session_resumed()


## As TrackerLink.setTrackerMode: a camera mode with no calibration this session starts one.
func set_tracker_mode(mode: String) -> void:
	_tracker_mode = mode
	if mode == "off":
		_calibration_steps = []
	elif not _session_calibrated and _calibration_steps.is_empty():
		_start_calibration("lean_2d" if mode == "lean_2d" else "lean_x", false)


## As TrackerLink.requestCalibration: the rider asked, so every step runs.
func request_calibration(mode: String) -> void:
	_start_calibration(mode, true)


func _start_calibration(mode: String, force: bool) -> void:
	_calibration_mode = mode
	_session_calibrated = true
	calibrations_started += 1
	if not force and _extremes.has(mode):
		_calibration_steps = ["centre"]
	else:
		_calibration_steps = ["centre", "left", "right"]
		if mode == "lean_2d":
			_calibration_steps += ["in", "back"]
	_calibration_count = _calibration_steps.size()
	_calibration_step_left = CALIBRATION_STEPS[_calibration_steps[0]]
	_calibration_report_left = 0.0


## Whether a scripted calibration is running (for tests).
func is_calibrating() -> bool:
	return not _calibration_steps.is_empty()


## Seconds the running scripted calibration still takes (0 when none runs). The session is
## paused meanwhile, so tests wait this out before the intro card counts down.
func calibration_left_sec() -> float:
	if _calibration_steps.is_empty():
		return 0.0
	var left := _calibration_step_left
	for step in _calibration_steps.slice(1):
		left += CALIBRATION_STEPS[step]
	return left + 0.05


## Steps in the running (or last) calibration (for tests).
func calibration_step_count() -> int:
	return _calibration_count


## What bridge field 9 would read: off, calibrating, or tracking.
func tracker_state() -> int:
	if _tracker_mode == "off":
		return InputBus.TRACKER_OFF
	return InputBus.TRACKER_CALIBRATING if not _calibration_steps.is_empty() else InputBus.TRACKER_TRACKING


func request_end() -> void:
	_end_requested = true
	match _phase:
		"intro", "playing":
			_begin_ending()
		"", "awaiting_end":
			_finish()


func _process(delta: float) -> void:
	_calibrate(delta)
	_refresh_paused()
	if _paused or _phase in ["", "awaiting_end", "finished"]:
		return
	_elapsed += delta
	match _phase:
		"intro":
			_intro_left -= delta
			if _intro_left <= 0.0:
				_phase = "playing"
		"playing":
			_played += delta
			var duration: float = _segment.duration_sec
			var stop_at := -1.0
			if duration >= 0:
				stop_at = duration if _segment.end_mode == "timer" else duration * 1.5
			if stop_at >= 0 and _played >= stop_at:
				_begin_ending()
		"ending":
			_grace_left -= delta
			if _grace_left <= 0.0:
				_results.append(_zero_result())
				_advance()


func _start_segment(index: int) -> void:
	var planned: Dictionary = _plan.segments[index]
	_segment = {
		"index": index,
		"count": _plan.segments.size(),
		"game_id": planned.game_id,
		"duration_sec": planned.duration_sec,
		"intro_sec": INTRO_SEC,
		"end_mode": planned.get("end_mode", "game" if planned.duration_sec < 0 else _timed_end_mode(planned.game_id)),
		"role": planned.role,
		"difficulty": _plan.difficulty,
		"effort": planned.role == "work" or (planned.role == "free" and _effort_in_just_ride(planned.game_id)),
		"seed": randi(),
		"audio": _plan.get("audio", DEFAULT_AUDIO),
		"params": planned.get("params", {}),
	}
	_phase = "intro"
	_intro_left = INTRO_SEC
	_played = 0.0
	_session._on_segment_started(_wire(_segment))


func _begin_ending() -> void:
	_phase = "ending"
	_grace_left = GRACE_SEC
	_session._on_segment_ending()


func _advance() -> void:
	var next: int = _segment.index + 1
	if _end_requested:
		_finish()
	elif next < _plan.segments.size():
		_start_segment(next)
	elif _segment.duration_sec < 0:
		_phase = "awaiting_end"
	else:
		_finish()


func _finish() -> void:
	_phase = "finished"
	var score := 0.0
	var stars := 0
	for r in _results:
		score += float(r.get("score", 0))
		stars += int(r.get("stars", 0))
	var summary := {
		"ride_id": null,
		"results": _results,
		"totals": {"score": score, "stars": stars, "segments": _results.size(), "elapsed_sec": int(_elapsed)},
		"bests": {},
	}
	var in_visit := _plan.has("visit_id")
	if in_visit:
		summary = hub.plan_finishing(_plan, summary)
	_session._on_session_finished(_wire(summary))
	if in_visit:
		hub.plan_finished(_plan, summary)


## As SessionPlans.kt: a timed Just Ride uses the game's own end mode (Kart Race ends on a lap
## line); circuit slots always end on the timer.
func _timed_end_mode(game_id: String) -> String:
	if str(_plan.get("kind", "")) != "just_ride":
		return "timer"
	var info := GameRegistry.info(game_id)
	return info.timed_end_mode if info else "timer"


func _effort_in_just_ride(game_id: String) -> bool:
	var info := GameRegistry.info(game_id)
	return info != null and info.effort_in_just_ride


func _calibrate(delta: float) -> void:
	if _calibration_steps.is_empty():
		return
	var step: String = _calibration_steps[0]
	_calibration_step_left -= delta
	_calibration_report_left -= delta
	var done := _calibration_step_left <= 0.0
	if _calibration_report_left <= 0.0 or done:
		_calibration_report_left = CALIBRATION_REPORT_SEC
		var fraction: float = 1.0 if done else 1.0 - _calibration_step_left / CALIBRATION_STEPS[step]
		_session._on_calibration_progress(step, fraction,
			_calibration_count - _calibration_steps.size(), _calibration_count, 1, "")
	if done:
		_calibration_steps.pop_front()
		if not _calibration_steps.is_empty():
			_calibration_step_left = CALIBRATION_STEPS[_calibration_steps[0]]
		elif _calibration_count > 1:
			_extremes[_calibration_mode] = true
			if _calibration_mode == "lean_2d":
				_extremes["lean_x"] = true


func _zero_result() -> Dictionary:
	return {"game_id": _segment.get("game_id", ""), "score": 0, "stars": 0, "won": null, "skipped": false, "stats": {}}


func _wire(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))
