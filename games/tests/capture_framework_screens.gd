extends SceneTree
## Screenshots of the framework's own screens, for UI reviews (framework/ui/UI_STYLE.md): every
## calibration step and strip, and the session summary in its main shapes. Not headless; needs
## a window:
##   $GODOT_BIN --path games -s res://tests/capture_framework_screens.gd -- --out=DIR
## Optional: --game=dodge_ball (the camera game behind the calibration shots, and the theme of
## the single-game summaries), --full (full-size PNGs; half size by default, as the tablet reads
## from the saddle), --only=calibration|summary.
##
## Plays a local Just Ride of the game, then saves:
##   calib_1_centre.png … calib_5_in.png     each step of a lean_2d run, with its countdown
##   calib_6_retry.png                        a retry with its hint
##   calib_7_fallback.png                     a step that fell back to the usual range
##   calib_8_needs.png                        "tap to calibrate"
##   calib_9_lost.png, calib_10_off.png       the "can't see you" and "camera off" strips in play
##   summary_1_single.png                     the real summary after End (one game)
##   summary_2_best.png                       one game, three stars and a new best
##   summary_3_nostars.png                    one game, no stars, a best to beat
##   summary_4_circuit.png                    a five-game circuit, finished, with a best
##   summary_5_early.png                      a circuit ended early (games not played)
##   summary_6_long.png                       nine rows with long names (the list scrolls)
##   summary_7_kart.png                       a Kart Race Just Ride (no ui_theme: the house look)
## Each line it prints carries the frame's draw calls.

var _session: Node
var _director: Node
var _bus: Node
var _out := "user://captures"
var _game := "dodge_ball"
var _full := false
var _only := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--game="):
			_game = arg.get_slice("=", 1)
		elif arg.begins_with("--only="):
			_only = arg.get_slice("=", 1)
		elif arg == "--full":
			_full = true
	DirAccess.make_dir_recursive_absolute(_out)
	_session = root.get_node("Session")
	_director = _session.director
	_bus = root.get_node("InputBus")
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": 600,
		"segments": [{"game_id": _game, "role": "free", "duration_sec": 600, "end_mode": "timer"}]})
	var overlay: Node = _director.calibration
	# Wait for the game to load (the calibration starts once it has).
	var deadline := Time.get_ticks_msec() + 30000
	while not _session.is_calibrating() and Time.get_ticks_msec() < deadline:
		await process_frame
	if _only != "summary":
		await _calibration_shots(overlay)
	while _session.is_calibrating() and Time.get_ticks_msec() < deadline:
		await process_frame
	if _only != "calibration":
		await _summary_shots()
	quit()


## Drives the overlay by hand (its _process off), so each state holds still for its shot.
func _calibration_shots(overlay: Node) -> void:
	# The scripted run first: its centre 3-2-1 as it really plays.
	await create_timer(1.2).timeout
	overlay.set_process(false)
	var steps := [["centre", 0.4, 0], ["left", 0.55, 1], ["right", 0.8, 2], ["in", 0.3, 3], ["back", 0.95, 4]]
	var n := 1
	for s in steps:
		await _progress(overlay, s[0], s[1], s[2], 5, 1, "")
		_shot("calib_%d_%s" % [n, s[0]])
		n += 1
	await _progress(overlay, "left", 0.2, 1, 5, 2, "too_small")
	_shot("calib_6_retry")
	await _progress(overlay, "right", 0.5, 2, 5, 3, "used_default")
	_shot("calib_7_fallback")
	overlay._show("needs")
	await _frames(20)
	_shot("calib_8_needs")
	# The strips sit in the HUD's status slot during play.
	overlay.set_process(true)
	while _director.phase_name() != "PLAYING":
		await process_frame
	overlay.set_process(false)
	overlay._show("lost")
	overlay._place_strip()
	await _frames(20)
	_shot("calib_9_lost")
	overlay._show("unavailable")
	await _frames(20)
	_shot("calib_10_off")
	overlay._show("")
	overlay.set_process(true)


func _progress(overlay: Node, step: String, fraction: float, index: int, count: int,
		attempt: int, reason: String) -> void:
	overlay._show("calibrating")
	overlay._update_progress({"step": step, "fraction": fraction, "step_index": index, "step_count": count,
		"attempt": attempt, "retry_reason": reason, "at_msec": Time.get_ticks_msec()})
	await _frames(30)  # let a step's entrance motion land


func _summary_shots() -> void:
	_bus._sim_cadence = 88.0
	await create_timer(4.0).timeout
	_session.request_end()
	var deadline := Time.get_ticks_msec() + 15000
	while not _director.summary_screen.visible and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(2.0).timeout
	_shot("summary_1_single")
	var screen: Node = _director.summary_screen
	var single := {"kind": "just_ride", "segments": [{"game_id": _game, "role": "free"}]}
	await _summary(screen, {"results": [_result(_game, 4820, 3)],
		"totals": {"score": 4820, "stars": 3, "elapsed_sec": 1265},
		"bests": {"score": true, "stars": true, "previous_score": 3900, "previous_stars": 2}}, single, "summary_2_best")
	await _summary(screen, {"results": [_result(_game, 140, 0)],
		"totals": {"score": 140, "stars": 0, "elapsed_sec": 312},
		"bests": {"previous_score": 5400, "previous_stars": 2}}, single, "summary_3_nostars")
	var games := ["cadence_karaoke", "dodge_ball", "tug_of_war", "safe_cracker", "kart_race"]
	var roles := ["warmup", "work", "recovery", "work", "cooldown"]
	var segments := []
	var results := []
	for i in games.size():
		segments.append({"game_id": games[i], "role": roles[i]})
		results.append(_result(games[i], 600 + i * 450, (i + 1) % 4))
	results[3] = {"game_id": "safe_cracker", "score": 0, "stars": 0, "skipped": true}
	var circuit := {"kind": "circuit", "segments": segments}
	await _summary(screen, {"results": results, "totals": {"score": 6150, "stars": 6, "elapsed_sec": 1830},
		"bests": {"score": true, "previous_score": 5200, "previous_stars": 5}}, circuit, "summary_4_circuit")
	await _summary(screen, {"results": results.slice(0, 2), "totals": {"score": 1650, "stars": 3, "elapsed_sec": 640},
		"bests": {}}, circuit, "summary_5_early")
	var long_segments := []
	var long_results := []
	for i in 9:
		long_segments.append({"game_id": games[i % games.size()], "role": roles[i % roles.size()]})
		long_results.append(_result(games[i % games.size()], 99999, i % 4))
	await _summary(screen, {"results": long_results, "totals": {"score": 899991, "stars": 12, "elapsed_sec": 4000},
		"bests": {"previous_score": 999999, "previous_stars": 27}}, {"kind": "circuit", "segments": long_segments}, "summary_6_long")
	await _summary(screen, {"results": [_result("kart_race", 2400, 2)], "totals": {"score": 2400, "stars": 2, "elapsed_sec": 900},
		"bests": {}}, {"kind": "just_ride", "segments": [{"game_id": "kart_race", "role": "free"}]}, "summary_7_kart")


func _summary(screen: Node, summary: Dictionary, plan: Dictionary, shot: String) -> void:
	screen.show_summary(summary, plan, _looks())
	await create_timer(2.0).timeout  # the entrance motion has landed
	_shot(shot)


## The looks the session collected, plus the other games' (as each sets it in a session), so a
## circuit's rows show every accent.
func _looks() -> Dictionary:
	var kit: GDScript = load("res://framework/ui/GameTheme.gd")
	var looks := {
		"cadence_karaoke": kit.new(Color(1.0, 0.45, 0.8), Color("12052a"), 0.25, true),
		"safe_cracker": kit.new(Color("e8b04a"), Color("14110d")),
		"tug_of_war": kit.new(Color("ff9f1c"), Color("2a160b"), 0.12),
	}
	looks.merge(_director.looks, true)
	return looks


static func _result(game_id: String, score: int, stars: int) -> Dictionary:
	return {"game_id": game_id, "score": score, "stars": stars, "won": null, "skipped": false}


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(state: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if not _full:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s.png" % [_out, state]
	img.save_png(path)
	print("CAPTURE %s fps=%d draw_calls=%d" % [path, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
