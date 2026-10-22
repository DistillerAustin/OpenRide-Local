extends SceneTree
## Desktop screenshots of Kart Race's items (#43) (not headless; needs a window):
##   $GODOT_BIN --path games -s res://tests/capture_kart_items.gd -- --out=DIR
## Starts a local open-ended Just Ride, pedals up and, once racing, saves: a held close-up of a
## pod row, then the rider's shield, a puck in flight, a drone chasing, a goo puddle (held
## camera) and the draft magnet's beam, each from the chase camera unless noted.

var _session: Node
var _director: Node  # untyped: a -s script compiles before the autoloads exist
var _held := KEY_NONE
var _out := "user://captures"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = 4.0
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": -1,
		"segments": [{"game_id": "kart_race", "role": "free", "duration_sec": -1}]})
	var deadline := Time.get_ticks_msec() + 30000
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	if _director.phase_name() != "PLAYING":
		print("CAPTURE FAILED: the game never started")
		quit(1)
		return
	var game: Node = _director.game
	_key(KEY_EQUAL, true)
	await create_timer(0.5).timeout
	_key(KEY_EQUAL, false)
	while game.flow != game.Flow.RACING:
		await process_frame
	Engine.time_scale = 1.0
	var cam = game.camera
	var track = game.track
	var items = game.items

	# 1. A pod row, held camera, low and to the side.
	await _drive(game, 2.0)
	var row_s: float = items.pods[0].s
	var eye: Vector3 = track.position_at(track.wrap(row_s - 9.0), 4.5) + Vector3.UP * 1.6
	var at: Vector3 = track.position_at(row_s, -0.5) + Vector3.UP * 1.0
	_hold(cam, eye, at, 50.0)
	await create_timer(0.6).timeout
	_save("items_pods")
	cam.hold = false
	await _drive(game, 8.0)

	# 2. A puck in flight, frozen, from behind and above it.
	items.give(0, "puck")
	items.use(0)
	await _drive(game, 0.12)
	var flow = game.flow
	game.flow = game.Flow.IDLE
	var puck = items.shots[items.shots.size() - 1]
	_hold(cam, _behind(puck.pos, puck.heading, 4.0, 1.6, 1.2), puck.pos + Vector3.UP * 0.3, 55.0)
	await create_timer(0.4).timeout
	_save("items_puck")

	# 3. A drone: thaw, fire, freeze shortly after, from beside it.
	game.flow = flow
	items.give(0, "drone")
	items.use(0)
	await _drive(game, 0.25)
	game.flow = game.Flow.IDLE
	var drone = items.shots[items.shots.size() - 1]
	var dpos: Vector3 = drone.pos + Vector3.UP * drone.height
	_hold(cam, _behind(dpos, drone.heading, 2.4, 1.3, 0.9), dpos, 50.0)
	await create_timer(0.4).timeout
	_save("items_drone")
	game.flow = flow
	cam.hold = false

	# 4. A goo puddle, a held camera looking back at it.
	await _drive(game, 2.0)
	items.give(0, "goo")
	items.use(0)
	await _drive(game, 0.5)
	game.flow = game.Flow.IDLE
	var goo = items.goos[items.goos.size() - 1]
	var yaw: float = track.yaw_at(goo.s)
	_hold(cam, _behind(goo.pos, yaw, 4.2, 2.0, 1.4), goo.pos + Vector3.UP * 0.1, 45.0)
	await create_timer(0.6).timeout
	_save("items_goo")
	game.flow = flow
	cam.hold = false

	# 5. The shield on the rider (chase camera).
	items.give(0, "shield")
	items.use(0)
	await _drive(game, 0.8)
	_save("items_shield")

	# 6. The magnet, once a kart is in range ahead.
	var limit: float = game.sim_time + 40.0
	while game.sim_time < limit:
		await _drive(game, 0.1)
		var k = game.race.karts[0]
		var ahead: int = items._ahead_of(k)
		if ahead >= 0:
			var gap: float = game.race.progress(ahead) - game.race.progress(0)
			if gap > 8.0 and gap < 20.0:
				break
	items.give(0, "magnet")
	items.use(0)
	await _drive(game, 0.6)
	_save("items_magnet")
	quit()


func _hold(cam, eye: Vector3, at: Vector3, fov: float) -> void:
	cam.held = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)
	cam.hold = true
	cam.fov = fov


## A point `back` metres behind `pos` along `yaw`, `up` above and `side` to the right.
func _behind(pos: Vector3, yaw: float, back: float, up: float, side: float) -> Vector3:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := fwd.cross(Vector3.UP)
	return pos - fwd * back + Vector3.UP * up + right * side


func _drive(game: Node, seconds: float) -> void:
	var until: float = game.sim_time + seconds
	while game.sim_time < until:
		await process_frame
		_steer(game)


## Arrow keys toward the racing line, using the track model.
func _steer(game: Node) -> void:
	var race = game.race
	if race == null:
		return
	var k = race.karts[0]
	var aim: float = race.track.racing_line(k.s + 12.0) * 0.6
	# Where the kart will be in half a second (sim_kart_check's driver): a key held until the
	# line is reached starts a tight drift and runs wide.
	var d_ahead: float = k.d - k.speed * sin(angle_difference(race.track.yaw_at(k.s), k.heading)) * 0.5
	var want := KEY_NONE
	if aim - d_ahead > 0.7:
		want = KEY_RIGHT
	elif aim - d_ahead < -0.7:
		want = KEY_LEFT
	if want != _held:
		if _held != KEY_NONE:
			_key(_held, false)
		if want != KEY_NONE:
			_key(want, true)
		_held = want


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img.get_width() < 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("CAPTURE %s fps=%d draw_calls=%d primitives=%d" % [path, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
