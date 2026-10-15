extends SceneTree
## Desktop screenshots of Kart Race's tracks (#43, the world): for each track (and direction),
## the grid, two chase shots while racing, and held "drone" views along the lap. Not headless.
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/capture_world.gd -- --out=DIR
##     [--tracks=meadow_ring,canyon_dash] [--reversed] [--nohud] [--drone=6]

var _session: Node
var _director: Node  # untyped: a -s script compiles before the autoloads exist
var _held := KEY_NONE


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://captures"
	var tracks: Array = []
	var reversed := false
	var hud := true
	var drones := 4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--tracks="):
			tracks = Array(arg.get_slice("=", 1).split(","))
		elif arg == "--reversed":
			reversed = true
		elif arg == "--nohud":
			hud = false
		elif arg.begins_with("--drone="):
			drones = int(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out)
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = 4.0
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": -1,
		"segments": [{"game_id": "kart_race", "role": "free", "duration_sec": -1}]})
	var deadline := Time.get_ticks_msec() + 30000
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	var game: Node = _director.game
	_director.hud.visible = hud
	if tracks.is_empty():
		tracks = KartTracks.CUP
	_key(KEY_EQUAL, true)
	await create_timer(0.5).timeout
	_key(KEY_EQUAL, false)
	for id in tracks:
		var guard := 0
		while (game.current.track_id != id or game.current.reversed != reversed) and guard < 12:
			game._board.hide_board()
			var t0 := Time.get_ticks_usec()
			game._begin_race()
			guard += 1
			if game.current.track_id == id and game.current.reversed == reversed:
				print("BUILD %s %.0f ms budget=%s" % [id, (Time.get_ticks_usec() - t0) / 1000.0, game.world.draw_budget()])
		game._start_countdown()
		var label := "%s_%s" % [id, "rev" if reversed else "fwd"]
		await create_timer(1.0).timeout
		_save(game, "%s/%s_grid.png" % [out, label])
		for shot in [["race", 10.0], ["lap", 16.0]]:
			var until: float = game.sim_time + shot[1]
			while game.sim_time < until:
				await process_frame
				_steer(game)
			_save(game, "%s/%s_%s.png" % [out, label, shot[0]])
		# Drone views: a held camera behind and above the road at points round the lap.
		game._kart_hud.visible = false
		_director.hud.visible = false
		var track = game.track
		var cam = game.camera
		for i in drones:
			var s: float = track.length * (i + 0.5) / drones
			var eye: Vector3 = track.position_at(s, 0.0) + Vector3.UP * 4.0
			var back: Vector3 = track.position_at(track.wrap(s - 14.0), 0.0) + Vector3.UP * 3.2
			var at: Vector3 = track.position_at(track.wrap(s + 30.0), 0.0) + Vector3.UP * 1.0
			cam.held = Transform3D(Basis.looking_at(at - back, Vector3.UP), back)
			cam.hold = true
			await create_timer(0.3).timeout
			_save(game, "%s/%s_drone%d.png" % [out, label, i])
		cam.hold = false
		game._kart_hud.visible = hud
		_director.hud.visible = hud
	quit()


func _steer(game: Node) -> void:
	var race = game.race
	if race == null:
		return
	var k = race.karts[0]
	var aim: float = race.track.racing_line(k.s + 12.0) * 0.6
	var want := KEY_NONE
	if aim - k.d > 0.7:
		want = KEY_RIGHT
	elif aim - k.d < -0.7:
		want = KEY_LEFT
	if want != _held:
		if _held != KEY_NONE:
			_key(_held, false)
		if want != KEY_NONE:
			_key(want, true)
		_held = want


func _save(game: Node, path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img.get_width() < 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("CAPTURE %s fps=%d draw_calls=%d primitives=%d" % [path.get_file(), Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
