extends SceneTree
## Desktop screenshots of Dodge Ball in each lighting (not headless; needs a window):
##   $GODOT_BIN --path games -s res://tests/capture_dodge.gd -- --out=DIR
## Plays a local Just Ride, weaves with the arrow keys, and saves one PNG per time of day.
## Options: --nohud, --scenes=day,night, --mode=catch (set through the game, after it starts),
## --bonus (the power bonus glow), --close (wait for a ball near the bars before each shot),
## --perf (after each shot, vsync off for 3 s: prints the mean frame time, draw calls and
## vertices of the frame, for before/after comparisons on the desktop).
## With --play=SECONDS it instead rides that long above the cadence floor and the power target
## (for Movie Maker: add --write-movie FILE.avi --fixed-fps 30 to record the game's own mix,
## reverb and all, without playing a sound).

var _session: Node
var _director: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://captures"
	var hud := true
	var play_sec := 0.0
	var intro := false
	var bonus := false
	var mode := ""
	var perf := false
	var close := false
	var scenes := ["dawn", "day", "dusk", "night"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg == "--nohud":
			hud = false
		elif arg.begins_with("--scenes="):
			scenes = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--mode="):
			# Set through the game once it plays: writing the options file here was overwritten by
			# GameOptions' cached copy on the first change_option (the mode never took effect).
			mode = arg.get_slice("=", 1)
		elif arg == "--perf":
			perf = true
		elif arg == "--close":
			close = true
		elif arg == "--bonus":
			bonus = true
		elif arg == "--intro":
			intro = true
		elif arg.begins_with("--play="):
			play_sec = float(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out)
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = 4.0
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": -1,
		"segments": [{"game_id": "dodge_ball", "role": "free", "duration_sec": -1}]})
	if intro:
		# The intro card, once the calibration has run.
		Engine.time_scale = 1.0
		while _session.is_calibrating():
			await process_frame
		await create_timer(1.5).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/dodge_intro.png" % out)
		print("CAPTURE %s/dodge_intro.png" % out)
		Engine.time_scale = 4.0
	var deadline := Time.get_ticks_msec() + 20000
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	if _director.phase_name() != "PLAYING":
		print("CAPTURE FAILED: the game never started")
		quit(1)
		return
	var game: Node = _director.game
	_director.hud.visible = hud
	if mode != "":
		game.change_option("mode", mode)
	if bonus:
		# A power target under the simulator's power, so the bonus shows (a local plan has none).
		game.logic.target_watts = 100.0
		_director.hud.metrics.set_power_band(100.0)
	var key := KEY_LEFT
	if play_sec > 0.0:
		game.change_option("scene", scenes[0])
		# Pedal up past the floor, then add resistance until the power bonus is on.
		_key(KEY_EQUAL, true)
		await create_timer(1.5).timeout
		_key(KEY_EQUAL, false)
		_key(KEY_BRACKETRIGHT, true)
		await create_timer(1.2).timeout
		_key(KEY_BRACKETRIGHT, false)
		var t := 0.0
		while t < play_sec:
			_key(key, true)
			await create_timer(0.45).timeout
			_key(key, false)
			key = KEY_RIGHT if key == KEY_LEFT else KEY_LEFT
			t += 0.45
		quit()
		return
	for scene in scenes:
		game.change_option("scene", scene)
		for i in 6:
			_key(key, true)
			await create_timer(0.4).timeout
			_key(key, false)
			key = KEY_RIGHT if key == KEY_LEFT else KEY_LEFT
		if close:
			# A ball closing in (within 0.5-0.9 s of the bars), so the shot shows one up close.
			var wait_until := Time.get_ticks_msec() + 8000
			while Time.get_ticks_msec() < wait_until and not _ball_close(game):
				await process_frame
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/dodge_%s.png" % [out, scene])
		print("CAPTURE %s/dodge_%s.png fps=%d draw_calls=%d" % [out, scene, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		if perf:
			await _measure(scene)
	game.change_option("scene", "auto")
	quit()


func _ball_close(game: Node) -> bool:
	for ball in game.logic.balls:
		if ball.eta > 0.5 and ball.eta < 0.9:
			return true
	return false


## Mean frame time over 3 s with vsync off, and the peak draw calls and vertices of a frame.
func _measure(scene: String) -> void:
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in 10:
		await process_frame
	var frames := 0
	var draws := 0.0
	var prims := 0.0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 3000000:
		await process_frame
		frames += 1
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims = maxf(prims, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / frames
	print("PERF %s frame_ms=%.2f draw_calls=%d primitives=%d" % [scene, ms, draws, prims])
	DisplayServer.window_set_vsync_mode(vsync)


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
