extends SceneTree
## Desktop screenshots of Safe Cracker (not headless; needs a window):
##   $GODOT_BIN --path games -s res://tests/capture_safe.gd -- --out=DIR
## Plays a local Just Ride and sets the game's state by hand for each shot. With --play=SECONDS
## it instead cracks safes with a scripted rider (for Movie Maker: add --write-movie FILE.avi
## --fixed-fps 30).
##
## --nohud hides the HUD (the game's banner stays), for art reviews. --measure=SECONDS (default
## off) turns vsync off and, in the office with the needle sweeping, prints the average frame
## time, the viewport's CPU and GPU render time and the draw calls (min/avg/max) over that many
## seconds, then goes on to the shots. Every CAPTURE line carries the frame's draw calls.

var _session: Node
var _director: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://captures"
	var play_sec := 0.0
	var measure_sec := 0.0
	var nohud := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--play="):
			play_sec = float(arg.get_slice("=", 1))
		elif arg.begins_with("--measure="):
			measure_sec = float(arg.get_slice("=", 1))
		elif arg == "--nohud":
			nohud = true
	DirAccess.make_dir_recursive_absolute(out)
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = 4.0
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": -1,
		"segments": [{"game_id": "safe_cracker", "role": "free", "duration_sec": -1,
			"params": {"power_cap_watts": 120.0}}]})
	var deadline := Time.get_ticks_msec() + 20000
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	if _director.phase_name() != "PLAYING":
		print("CAPTURE FAILED: the game never started")
		quit(1)
		return
	var game: Node = _director.game
	if nohud and game.hud:
		game.hud.visible = false
	if measure_sec > 0.0:
		await _measure(game, measure_sec)
	if play_sec > 0.0:
		game.change_option("scene", "random")
		await _ride(game, play_sec)
		quit()
		return
	var places := ["office", "bank", "museum", "cabin", "lab", "library"]
	for place in places:
		game.change_option("scene", place)
		game.logic.reading = float(game.logic.target()) - 6.0
		game.logic.progress = 0.8
		for i in 6:
			await process_frame
		_shot(out, "safe_%s" % place)
	game.change_option("scene", "office")
	game.change_option("hints", "hide")
	for i in 6:
		await process_frame
	_shot(out, "safe_hidden")
	game.change_option("hints", "show")
	# Unpowered, and an alarm.
	game.logic.cadence_min = 999.0
	for i in 6:
		await process_frame
	_shot(out, "safe_unpowered")
	game.logic.cadence_min = 60.0
	game.logic.alarm_left = 2.0
	for i in 6:
		await process_frame
	_shot(out, "safe_alarm")
	# The door swinging open.
	game.logic.alarm_left = 0.0
	game._dial.door_open = 0.6
	game._dial.refresh()
	await process_frame
	_shot(out, "safe_door_half")
	# On the target (the reading turns green), a tumbler's light popping, then a crack's banner.
	game._dial.door_open = 0.0
	game.logic.reading = float(game.logic.target())
	for i in 3:
		await process_frame
	_shot(out, "safe_on_target")
	game.logic.tumbler = 1
	game._handle({"type": "tumbler", "index": 0})
	for i in 4:
		await process_frame
	_shot(out, "safe_tumbler_pop")
	game._handle({"type": "vault_open", "points": 1150.0})
	await create_timer(0.5).timeout
	_shot(out, "safe_cracked")
	await create_timer(1.1).timeout
	_shot(out, "safe_open")  # the door all the way open, sparkles rising
	quit()


func _shot(out: String, name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("CAPTURE %s/%s.png draw_calls=%d" % [out, name, _draw_calls()])


func _draw_calls() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


## Desktop frame cost in the office with the needle sweeping (so the dial redraws every frame):
## vsync off, the average wall-clock frame, the viewport's CPU and GPU render time, draw calls.
func _measure(game: Node, seconds: float) -> void:
	game.change_option("scene", "office")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30:
		await process_frame
	var frames := 0
	var cpu := 0.0
	var gpu := 0.0
	var calls := [1 << 30, 0, 0]
	var start := Time.get_ticks_usec()
	var end := start + int(seconds * 1e6)
	while Time.get_ticks_usec() < end:
		game.logic.reading = 50.0 + 45.0 * sin(frames * 0.05)
		await process_frame
		frames += 1
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var dc := _draw_calls()
		calls = [mini(calls[0], dc), calls[1] + dc, maxi(calls[2], dc)]
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / frames
	print("MEASURE frames=%d frame_ms=%.3f render_cpu_ms=%.3f render_gpu_ms=%.3f draw_calls=%d/%.1f/%d" % [
		frames, ms, cpu / frames, gpu / frames, calls[0], float(calls[1]) / frames, calls[2]])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


## A scripted rider: nudges the simulated resistance toward the current target with the bracket
## keys, holding it there.
func _ride(game: Node, seconds: float) -> void:
	var bus: Node = root.get_node("InputBus")
	var held := 0
	for frame in roundi(seconds * 30.0):
		var want := float(game.logic.target()) if not game.logic.is_open() else 30.0
		var key := 0
		if bus.resistance < want - 1.0:
			key = KEY_BRACKETRIGHT
		elif bus.resistance > want + 1.0:
			key = KEY_BRACKETLEFT
		if key != held:
			if held != 0:
				_key(held, false)
			if key != 0:
				_key(key, true)
			held = key
		await process_frame
	if held != 0:
		_key(held, false)


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
