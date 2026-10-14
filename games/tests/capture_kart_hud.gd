extends SceneTree
## Desktop screenshots of Kart Race's HUD and flow screens (#43, the presentation pass); needs a
## window, not headless:
##   $GODOT_BIN --path games -s res://tests/capture_kart_hud.gd -- --out=DIR [--prefix=hud]
## Saves PREFIX_countdown, _race (drifting, an item held), _roulette, _lap (the lap banner),
## _final (the final-lap banner), _results and _podium. The drift is the effects' scripted demo
## drift and the item is set by hand, so the shots don't need the other Phase 2 areas.

var _session: Node
var _director: Node  # untyped: a -s script compiles before the autoloads exist
var _held := KEY_NONE


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://captures"
	var prefix := "hud"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--prefix="):
			prefix = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = 4.0
	_session._local.start({"kind": "just_ride", "plan_id": "capture", "difficulty": "standard", "total_sec": 600,
		"segments": [{"game_id": "kart_race", "role": "free", "duration_sec": 600}]})
	var deadline := Time.get_ticks_msec() + 30000
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	if _director.phase_name() != "PLAYING":
		print("CAPTURE FAILED: the game never started")
		quit(1)
		return
	var game: Node = _director.game
	game._fx.demo_drifts = true
	game.race.laps = 2
	_key(KEY_EQUAL, true)
	await create_timer(0.5).timeout
	_key(KEY_EQUAL, false)
	# The countdown's "2".
	while game.race.countdown > 1.6 or game.flow != game.Flow.COUNTDOWN:
		await process_frame
	await create_timer(0.15).timeout
	_save("%s/%s_countdown.png" % [out, prefix])
	# Racing: an item held, a drift in a corner.
	var k = game.race.karts[0]
	k.item = "turbo"
	var fx = game._fx
	var shot := false
	var limit: float = game.sim_time + 40.0
	while game.sim_time < limit:
		await process_frame
		_steer(game)
		k.item = "turbo" if k.roulette_time <= 0.0 else k.item
		var curv: float = absf(game.race.track.curvature(k.s))
		if game.race.time > 6.0 and curv > 0.008 and fx._drift_t[0] < 0.0:
			fx._drift_next[0] = 0.0
		if game.race.time > 6.0 and fx._drift_t[0] > 1.3:
			_save("%s/%s_race.png" % [out, prefix])
			shot = true
			break
	if not shot:
		_save("%s/%s_race.png" % [out, prefix])
	# The HUDs' share of the draw calls.
	for state in [[true, true], [false, true], [false, false]]:
		game._kart_hud.visible = state[0]
		_director.hud.visible = state[1]
		for i in 12:
			await process_frame
		print("CAPTURE draw_calls kart_hud=%s hud=%s: %d" % [state[0], state[1], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	game._kart_hud.visible = true
	_director.hud.visible = true
	if OS.get_cmdline_user_args().has("--probe"):
		var nodes: Array = game._kart_hud._gameplay.get_children() + game._kart_hud._root.get_children()
		for n in nodes:
			if not n.visible:
				continue
			n.visible = false
			for i in 12:
				await process_frame
			var without: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			n.visible = true
			for i in 12:
				await process_frame
			var with: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			print("CAPTURE probe %s: %d" % [n.name, with - without])
	# The roulette spinning.
	k.item = ""
	await create_timer(0.1).timeout
	k.item = "shield"
	k.roulette_time = 0.9
	var t := 0.0
	while t < 0.4:
		await process_frame
		t += 1.0 / 60.0
		k.roulette_time = maxf(0.0, k.roulette_time - 1.0 / 60.0)
		_steer(game)
	_save("%s/%s_roulette.png" % [out, prefix])
	while k.roulette_time > 0.0:
		await process_frame
		k.roulette_time = maxf(0.0, k.roulette_time - 1.0 / 60.0)
	# Banners.
	game._kart_hud.banner("LAP 2/3", 1.1)
	await create_timer(0.55).timeout
	_save("%s/%s_lap.png" % [out, prefix])
	await create_timer(1.4).timeout
	game._kart_hud.banner("FINAL LAP!", 1.6, "Give it everything", true)
	await create_timer(0.6).timeout
	_save("%s/%s_final.png" % [out, prefix])
	# The results: race to the line quickly.
	game.current.is_final = true
	Engine.time_scale = 4.0
	while game.flow != game.Flow.RESULTS and not game.has_ended():
		await process_frame
		_steer(game)
	Engine.time_scale = 1.0
	await create_timer(1.6).timeout
	_save("%s/%s_results.png" % [out, prefix])
	while game.flow != game.Flow.PODIUM and not game.has_ended():
		await process_frame
	await create_timer(2.6).timeout
	_save("%s/%s_podium.png" % [out, prefix])
	quit()


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
	print("CAPTURE %s fps=%d draw_calls=%d primitives=%d" % [path, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
