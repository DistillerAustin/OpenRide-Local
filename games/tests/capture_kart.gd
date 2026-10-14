extends SceneTree
## Desktop screenshots of Kart Race (#43) (not headless; needs a window):
##   $GODOT_BIN --path games -s res://tests/capture_kart.gd -- --out=DIR
## Plays a local open-ended Just Ride, pedals up, steers toward the racing line with the arrow
## keys, and saves PNGs of each track in the cup, forward and reversed: on the grid, a few
## seconds into the race and further round the lap. --tracks=forward,reversed picks directions,
## --nohud hides the HUD, --intro also saves the intro card.
## With --play=SECONDS it instead races that long (for Movie Maker: add
## --write-movie FILE.avi --fixed-fps 30 to record the game's own mix without playing a sound).
## With --compose it saves the hero slice's four compositions as PREFIX_a..d_desktop.png
## (--prefix=godot): (a) the start grid under the title card, (b) the chase camera mid-corner
## with the full HUD during a drift, (c) a beauty close-up of karts on the grid, HUD hidden, and
## (d) the results board (a one-lap race, sped up). Shots are scaled to 1920x1080 when the
## window is smaller than the canvas.

var _session: Node
var _director: Node  # untyped: a -s script compiles before the autoloads exist
var _held := KEY_NONE


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://captures"
	var hud := true
	var play_sec := 0.0
	var intro := false
	var compose := false
	var prefix := "godot"
	var directions := ["forward", "reversed"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg == "--nohud":
			hud = false
		elif arg == "--intro":
			intro = true
		elif arg.begins_with("--tracks="):
			directions = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--play="):
			play_sec = float(arg.get_slice("=", 1))
		elif arg == "--compose":
			compose = true
		elif arg.begins_with("--prefix="):
			prefix = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = 4.0
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": -1,
		"segments": [{"game_id": "kart_race", "role": "free", "duration_sec": -1}]})
	if intro:
		Engine.time_scale = 1.0
		while _session.is_calibrating():
			await process_frame
		await create_timer(1.5).timeout
		_save("%s/kart_intro.png" % out)
		Engine.time_scale = 4.0
	var deadline := Time.get_ticks_msec() + 30000
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	if _director.phase_name() != "PLAYING":
		print("CAPTURE FAILED: the game never started")
		quit(1)
		return
	var game: Node = _director.game
	_director.hud.visible = hud
	if compose:
		await _compose(game, out, prefix)
		quit()
		return
	# Pedal up to ~100 rpm.
	_key(KEY_EQUAL, true)
	await create_timer(0.5).timeout
	_key(KEY_EQUAL, false)
	if play_sec > 0.0:
		var until: float = game.sim_time + play_sec
		while game.sim_time < until and is_instance_valid(game) and not game.has_ended():
			await process_frame
			_steer(game)
		quit()
		return
	var first := true
	for direction in directions:
		var track_id: String = game.current.track_id
		if not first or direction == "reversed":
			# The next race of the cup (the second time round is reversed).
			while game.current.reversed != (direction == "reversed"):
				game._board.hide_board()
				game._begin_race()
			game._start_countdown()
		first = false
		var label := "%s_%s" % [game.current.track_id, direction]
		await create_timer(1.2).timeout
		_save("%s/kart_%s_grid.png" % [out, label])
		for shot in [["race", 9.0], ["lap", 18.0]]:
			var until: float = game.sim_time + shot[1]
			while game.sim_time < until:
				await process_frame
				_steer(game)
			_save("%s/kart_%s_%s.png" % [out, label, shot[0]])
		print("CAPTURE %s done (%s)" % [label, track_id])
	quit()


func _compose(game: Node, out: String, prefix: String) -> void:
	_key(KEY_EQUAL, true)
	await create_timer(0.5).timeout
	_key(KEY_EQUAL, false)
	game.race.laps = 1  # (d) comes after one lap
	# (a) The fly-over's opening, title card up.
	_director.hud.visible = false
	await create_timer(0.75).timeout
	_save("%s/%s_a_desktop.png" % [out, prefix])
	# (c) Beauty close-up on the grid: a held camera low beside the last three karts.
	game._kart_hud.visible = false
	var track = game.track
	var cam = game.camera
	var eye: Vector3 = track.position_at(track.wrap(-26.5), -6.4) + Vector3.UP * 1.5
	var at: Vector3 = track.position_at(track.wrap(-33.5), 0.2) + Vector3.UP * 0.5
	cam.held = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)
	cam.hold = true
	cam.fov = 44.0
	await create_timer(0.4).timeout
	_save("%s/%s_c_desktop.png" % [out, prefix])
	cam.hold = false
	game._kart_hud.visible = true
	_director.hud.visible = true
	# (b) Racing: into a corner, drifting, full HUD.
	var fx = game._fx
	var shot := false
	var limit: float = game.sim_time + 60.0
	while game.sim_time < limit:
		await process_frame
		_steer(game)
		var k = game.race.karts[0]
		var curv: float = absf(game.race.track.curvature(k.s))
		if game.race.time > 9.0 and curv > 0.008 and fx._drift_t[0] < 0.0:
			fx._drift_next[0] = 0.0
		if game.race.time > 9.0 and curv > 0.006 and fx._drift_t[0] > 0.95 and _clear_view(game):
			_save("%s/%s_b_desktop.png" % [out, prefix])
			shot = true
			break
	if not shot:
		_save("%s/%s_b_desktop.png" % [out, prefix])
	# (d) Race to the line quickly, then the board.
	Engine.time_scale = 4.0
	while game.flow != game.Flow.RESULTS and not game.has_ended():
		await process_frame
		_steer(game)
	Engine.time_scale = 1.0
	await create_timer(1.6).timeout
	_save("%s/%s_d_desktop.png" % [out, prefix])


## No other kart between the chase camera and the rider's kart.
func _clear_view(game: Node) -> bool:
	var k = game.race.karts[0]
	var cam_pos: Vector3 = game.camera.global_position
	for i in range(1, game.race.karts.size()):
		var o: Vector3 = game.race.karts[i].pos
		var seg: Vector3 = k.pos - cam_pos
		var t: float = clampf((o - cam_pos).dot(seg) / seg.length_squared(), 0.0, 1.0)
		if (cam_pos + seg * t).distance_to(o) < 2.2 and t > 0.05 and t < 0.98:
			return false
	return true


## Arrow keys toward the racing line, using the track model.
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


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img.get_width() < 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("CAPTURE %s fps=%d draw_calls=%d" % [path, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
