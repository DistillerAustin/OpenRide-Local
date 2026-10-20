extends SceneTree
## Headless walkthrough of the Games hub on the desktop (spec §11), through its real screens
## and the desktop visit (LocalHub):
##   $GODOT_BIN --headless --path games -s res://tests/sim_hub_check.gd
## Enter → the hub's home → Kart Race's card → 5 min → Start → the plan runs (calibration, intro
## card, racing) → End (confirmed) → the result card reads "Back to games" → the hub, where the
## result shows on Kart Race's card → the 20 min circuit → Start → End mid-way → back to the hub
## (calibrated once for the whole visit) → Settings (music off) → Exit games → confirm →
## exit_hub("app") → visit_ended → a new visit. Prints PASS or FAIL and exits non-zero on failure.

const SPEED := 4.0

var _session: Node
var _director: Node
var _local: Node
var _failures: Array[String] = []
var _calls: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node("Session")
	_director = _session.director
	_local = _session._local
	Engine.time_scale = SPEED
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	await process_frame
	_local.hub.begin_visit()
	await _frames(10)
	var hub: Node = current_scene
	_expect(_director.phase_name() == "HUB", "the visit opens the hub")
	_expect(hub.nav.top_id() == "home", "the hub shows its home")
	_expect(Engine.max_fps == _director.HUB_MAX_FPS, "the hub runs at 30 fps")
	var first_visit: String = _session.visit_id

	# Kart Race, 5 minutes.
	hub.screen.game_cards["kart_race"].hit.pressed.emit()
	await _frames(3)
	_expect(hub.nav.top_id() == "game" and hub.screen.game_id == "kart_race", "Kart Race's card opens its screen")
	var game: Node = hub.screen
	game.length_picker.modes.pick("minutes")
	while int(game.length_picker.stepper.value()) > 5:
		game.length_picker.stepper.step(-1)
	_expect(game.request() == {"kind": "just_ride", "game_id": "kart_race", "mode": "minutes", "difficulty": "standard",
		"length": 5}, "the request is Kart Race for 5 min (%s)" % game.request())
	game.start_button.pressed.emit()
	await _frames(3)
	_expect(_session.active and _session.plan.plan_id == "just-ride:kart_race:minutes:5", "Start plays the plan")
	_expect(_session.plan.visit_id == first_visit, "the plan carries the visit")
	_expect(Engine.max_fps == _director.PLAY_MAX_FPS, "the game runs uncapped")
	# The first camera game calibrates (by itself, as on the bike), then the intro, then racing.
	await _until(func(): return _director.phase_name() == "PLAYING", 60.0, "Kart Race starts")
	await _wait(3.0)
	_director.pause_overlay.end_confirmed.emit()  # End, confirmed
	await _until(func(): return _director.summary_screen.visible, 20.0, "End shows the result card")
	_expect(_director.summary_screen.done_button.text == "Back to games", "the result card reads Back to games")
	var calibrations: int = _local.calibrations_started
	_director.summary_screen.done_button.pressed.emit()
	await _frames(10)
	hub = current_scene
	_expect(_director.phase_name() == "HUB" and hub.scene_file_path == _director.IDLE_SCENE,
		"Back to games returns to the hub")
	_expect(hub.nav.top_id() == "game", "the hub comes back on Kart Race's screen")
	_expect(_session.visit_id == first_visit, "still the same visit")
	_expect(not _local.hub_calls.any(func(c): return c[0] == "exit_hub"), "the result card doesn't exit")
	hub.screen.back.emit()
	await _frames(3)
	_expect(str(hub.state.visit.plans[0].plan_id) == "just-ride:kart_race:minutes:5", "the visit lists the plan")
	_expect(hub.screen.header.ride_label.text.begins_with("Ride so far"), "the header shows the ride so far")

	# The 20 min circuit, ended mid-way.
	hub.screen.circuit_cards["circuit-20"].hit.pressed.emit()
	await _frames(3)
	_expect(hub.nav.top_id() == "circuit", "a circuit's card opens its screen")
	hub.screen.difficulty.pick("easy")
	hub.screen.start_button.pressed.emit()
	await _frames(3)
	_expect(_session.active and _session.plan.plan_id == "circuit-20" and _session.plan.difficulty == "easy",
		"the circuit plays at its difficulty")
	_expect(str(_session.plan.calibrated) == "lean_x", "the visit's calibration carries into the next plan")
	await _until(func(): return _director.phase_name() == "PLAYING", 30.0, "the circuit's first game starts")
	await _wait(2.0)
	_director.pause_overlay.end_confirmed.emit()
	await _until(func(): return _director.summary_screen.visible, 20.0, "End shows the circuit's result card")
	_expect(_director.summary_screen.title_for(_session.plan, 1) == "Session ended early", "the circuit ended early")
	_session.back()  # Android back on the result card: to the hub as well
	await _frames(10)
	hub = current_scene
	_expect(_director.phase_name() == "HUB", "back on the result card returns to the hub")
	_expect(_local.calibrations_started == calibrations, "no calibration after the visit's first (%d → %d)" % [
		calibrations, _local.calibrations_started])
	hub.screen.back.emit()
	await _frames(3)
	_expect(hub.nav.top_id() == "home", "Back leads home")

	# Settings: music off, through update_setting.
	hub.screen.header.settings_button.pressed.emit()
	await _frames(3)
	_expect(hub.nav.top_id() == "settings", "the gear opens Settings")
	hub.screen.music.pick("off")
	await _frames(2)
	_expect(_local.hub_calls.back() == ["update_setting", "music", "off"], "music off goes to Kotlin")
	_expect(not bool(hub.state.audio.music), "hub_state confirms music off")
	_expect(not root.get_node("AudioDirector").music_enabled, "the hub's music stops")
	_session.back()
	await _frames(3)

	# Exit games, confirmed.
	var ended: Array = []
	_session.visit_ended.connect(func(r: Dictionary): ended.append(r))
	_session.back()  # on home: asks to exit
	_expect(hub.dialog.visible, "back on home asks to exit")
	var long_enough: bool = float(hub.state.visit.gameplay_sec) >= 60.0
	_expect(hub.dialog.act_button.text == ("Exit and save" if long_enough else "Exit"),
		"the exit says what happens to the ride (%s)" % hub.dialog.act_button.text)
	hub.dialog.keep_button.pressed.emit()
	_expect(not hub.dialog.visible and ended.is_empty(), "Keep playing keeps playing")
	hub.screen.header.exit_button.pressed.emit()
	hub.dialog.act_button.pressed.emit()
	await _frames(3)
	_expect(_local.hub_calls.any(func(c): return c == ["exit_hub", "app"]), "Exit sends exit_hub(app)")
	_expect(ended.size() == 1 and bool(ended[0].saved) == long_enough, "visit_ended says whether the ride was saved")
	await _until(func(): return _session.visit_id != first_visit, 10.0, "a new visit starts (re-entry)")
	await _frames(5)
	_expect(hub.nav.top_id() == "home" and not hub._saved_layer.visible, "the new visit opens home")

	Engine.time_scale = 1.0
	if _failures.is_empty():
		print("PASS sim hub")
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("FAIL sim hub")
		quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits `seconds` of game time.
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _until(cond: Callable, seconds: float, what: String) -> void:
	var left := seconds
	while not cond.call() and left > 0.0:
		await create_timer(0.1).timeout
		left -= 0.1
	_expect(cond.call(), what)
