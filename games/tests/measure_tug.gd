extends SceneTree
## Where Tug of War's frame goes, for the tablet (PowerVR GX6250: fill-rate and ALU bound, and
## CPU-bound on the main thread with the face tracker running). Needs a window, not headless:
##   $GODOT_BIN --path games -s res://tests/measure_tug.gd [-- --scale=3 --frames=120]
## Plays a local Just Ride (with a 30 s intro card), then prints, vsync off:
##   MEASURE tug phase=intro|play  draw_calls (the whole window and the 3D view), primitives,
##     objects, frame_ms, process_ms, the 3D view's render CPU ms (Compatibility has no GPU timer);
##   MEASURE tug cost=<part>  the 3D view's frame ms with that part hidden, at --scale times the
##     game's render size per axis (so the GPU, not the desktop's CPU, is the long bar), A/B
##     three times; then the losing view in a surge (pulled in, the river filling the screen);
##   MEASURE tug frame_cpu  GDScript per frame: `_on_frame` (logic, world, status) in µs.
## The desktop GPU is 30-50 times the tablet's and barely notices most parts even at --scale=4
## (they land inside the noise): read the shares, not the absolute numbers. --shot=FILE.png saves
## the intro's and the scaled view (FILE_intro.png, FILE.png); keep captures small.

var _frames := 120
var _scale := 3.0
var _shot := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			_shot = arg.get_slice("=", 1)
		elif arg.begins_with("--scale="):
			_scale = float(arg.get_slice("=", 1))
	var session: Node = root.get_node("Session")
	var director: Node = session.director
	session._local.start({"kind": "just_ride", "plan_id": "measure", "difficulty": "standard", "total_sec": -1,
		"segments": [{"game_id": "tug_of_war", "role": "free", "duration_sec": -1, "end_mode": "game",
			"intro_sec": 30, "params": {"ftp": 200.0, "bot_watts": 220.0, "surge_watts": 260.0}}]})
	var deadline := Time.get_ticks_msec() + 20000
	while director.phase_name() != "INTRO" and Time.get_ticks_msec() < deadline:
		await process_frame
	var game: Node = director.game
	var view: SubViewport = game.get_node("View3D")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	await _phase_stats("intro", view)
	if _shot != "":
		view.get_texture().get_image().save_png(_shot.replace(".png", "_intro.png"))
	director._intro_left = 0.0
	while director.phase_name() != "PLAYING":
		await process_frame
	game.logic._next_surge = 100000.0
	await _phase_stats("play", view)
	# GDScript per frame, steady state (the game's own _process stepped by hand).
	game.set_process(false)
	var t0 := Time.get_ticks_usec()
	for i in 600:
		game._on_frame(1.0 / 60.0)
	print("MEASURE tug frame_cpu on_frame_us=%.1f" % ((Time.get_ticks_usec() - t0) / 600.0))
	# GPU cost per part, at a scaled-up render size, with the rope held even (the intro's view).
	game.world.update_view(0.0, 0.0, 0.5, "", 80.0)
	var base_size := view.size
	view.size = Vector2i(roundi(base_size.x * _scale), roundi(base_size.y * _scale))
	var world: Node3D = game.world
	var parts := ["Water", "Scenery", "Decks", "Crowd", "Flames", "Lilies", "Rope", "Flag", "Bot", "Rig", "Sky"]
	var env: Environment = world._env.environment
	await _frame_ms(view)
	if _shot != "":
		var shot := view.get_texture().get_image()
		shot.resize(shot.get_width() / roundi(_scale), shot.get_height() / roundi(_scale))
		shot.save_png(_shot)
	for part in parts:
		# A/B/A/B/A/B, so the desktop's clock ramps cancel out: the median of three differences.
		var deltas: Array[float] = []
		var shown_ms := 0.0
		for rep in 3:
			var with_ms := await _frame_ms(view)
			_show(world, env, part, false)
			var without_ms := await _frame_ms(view)
			_show(world, env, part, true)
			deltas.append(with_ms - without_ms)
			shown_ms += with_ms / 3.0
		deltas.sort()
		print("MEASURE tug cost=%s frame_ms=%.3f saves=%.3f (%.3f..%.3f) size=%s" % [part, shown_ms, deltas[1], deltas[0], deltas[2], view.size])
	# The losing view: pulled in, the water filling the screen.
	world.update_view(0.0, -0.95, 1.0, "surge", 80.0)
	var lose := await _frame_ms(view)
	print("MEASURE tug cost=losing_surge frame_ms=%.3f" % lose)
	world.update_view(0.0, 0.0, 0.5, "", 80.0)
	view.size = base_size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	quit()


func _phase_stats(phase: String, view: SubViewport) -> void:
	for i in 30:
		await process_frame
	var rid := view.get_viewport_rid()
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var view_draws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var cpu := 0.0
	var proc := 0.0
	var start := Time.get_ticks_usec()
	for i in _frames:
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
	var frame_ms := (Time.get_ticks_usec() - start) / 1000.0 / _frames
	print("MEASURE tug phase=%s draw_calls=%d view3d_draw_calls=%d primitives=%d objects=%d frame_ms=%.2f process_ms=%.2f view3d_cpu_ms=%.3f " % [
		phase, draws, view_draws, prims, objects, frame_ms, proc / _frames, cpu / _frames])


func _frame_ms(view: SubViewport) -> float:
	for i in 10:
		await process_frame
	var start := Time.get_ticks_usec()
	for i in _frames:
		await process_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / _frames



func _show(world: Node3D, env: Environment, part: String, on: bool) -> void:
	if part == "Sky":
		env.background_mode = Environment.BG_SKY if on else Environment.BG_COLOR
	else:
		(world.get_node(part) as Node3D).visible = on
