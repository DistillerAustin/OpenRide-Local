extends SceneTree
## Screenshots of any game at its key UI states, for UI reviews (framework/ui/UI_STYLE.md). Not
## headless; needs a window:
##   $GODOT_BIN --path games -s res://tests/capture_ui_states.gd -- --game=dodge_ball --out=DIR
## Optional: --logic='{"power_cap":120}' (set on the game's `logic` once play starts: a local
## session sends no params), --role=work,
## --tension=CADENCE:RESISTANCE (the simulator's ride for the "tension" shot; default 45:35, a
## stall under every floor), --full (full-size PNGs; by default they're half size, 960x540,
## which is about how the tablet reads from the saddle).
##
## Plays a local timed Just Ride of the game and saves, in order:
##   <game>_1_intro.png    the intro card, after the calibration
##   <game>_2_play.png     4 s into play, riding briskly and weaving
##   <game>_3_mid.png      16 s in (a round, a wave, a streak usually shows by then)
##   <game>_4_tension.png  5 s after the ride drops to --tension (shield, alarm, slip, ease-off)
##   <game>_5_pause.png    the pause card
##   <game>_6_summary.png  the session summary after End
## Each line it prints carries the frame rate and the frame's draw calls, a rough budget check
## (the tablet is what counts: docs/GAMES.md).

var _session: Node
var _director: Node
var _bus: Node
var _out := "user://captures"
var _game := "dodge_ball"
var _full := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var logic_props := {}
	var role := "free"
	var tension := Vector2(45, 35)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--game="):
			_game = arg.get_slice("=", 1)
		elif arg.begins_with("--logic="):
			logic_props = JSON.parse_string(arg.substr(8))
		elif arg.begins_with("--role="):
			role = arg.get_slice("=", 1)
		elif arg.begins_with("--tension="):
			var parts := arg.get_slice("=", 1).split(":")
			tension = Vector2(float(parts[0]), float(parts[1]))
		elif arg == "--full":
			_full = true
	DirAccess.make_dir_recursive_absolute(_out)
	_session = root.get_node("Session")
	_director = _session.director
	_bus = root.get_node("InputBus")
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": 600,
		"segments": [{"game_id": _game, "role": role, "duration_sec": 600, "end_mode": "timer"}]})
	var deadline := Time.get_ticks_msec() + 30000
	while _session.is_calibrating() and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(1.5).timeout
	_shot("1_intro")
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	if _director.phase_name() != "PLAYING":
		print("CAPTURE FAILED: the game never started")
		quit(1)
		return
	var logic: Object = _director.game.get("logic")
	for key in logic_props:
		if logic:
			logic.set(key, logic_props[key])
	_bus._sim_cadence = 92.0
	_bus._sim_resistance = 45.0
	await _weave(4.0)
	_shot("2_play")
	await _weave(12.0)
	_shot("3_mid")
	_bus._sim_cadence = tension.x
	_bus._sim_resistance = tension.y
	await _weave(5.0)
	_shot("4_tension")
	_session.request_pause()
	await create_timer(0.8).timeout
	_shot("5_pause")
	_session.request_resume()
	await create_timer(0.5).timeout
	_session.request_end()
	deadline = Time.get_ticks_msec() + 15000
	while not _director.summary_screen.visible and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(0.8).timeout
	_shot("6_summary")
	quit()


## Leans left and right for `seconds`, so steering games move.
func _weave(seconds: float) -> void:
	var key := KEY_LEFT
	var t := 0.0
	while t < seconds:
		_key(key, true)
		await create_timer(0.5).timeout
		_key(key, false)
		key = KEY_RIGHT if key == KEY_LEFT else KEY_LEFT
		t += 0.5


func _shot(state: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if not _full:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s_%s.png" % [_out, _game, state]
	img.save_png(path)
	print("CAPTURE %s fps=%d draw_calls=%d" % [path, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
