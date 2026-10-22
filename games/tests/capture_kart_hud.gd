extends SceneTree
## Desktop screenshots of Kart Race's HUD and flow screens (#43, the presentation pass); needs a
## window, not headless:
##   $GODOT_BIN --path games -s res://tests/capture_kart_hud.gd -- --out=DIR [--prefix=hud]
## Saves PREFIX_countdown, _race (drifting, an item held), _drift (the meter at tier 2), _roulette, _lap (the lap banner),
## _final (the final-lap banner), _results and _podium. The drift is a real one (the arrow key
## held into a corner); the item is set by hand.

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
	var shot := false
	var limit: float = game.sim_time + 40.0
	while game.sim_time < limit:
		await process_frame
		k.item = "turbo" if k.roulette_time <= 0.0 else k.item
		var curv: float = game.race.track.curvature(game.race.track.wrap(k.s + 10.0))
		if game.race.time > 6.0 and (absf(curv) > 0.016 if k.drift_dir == 0 else curv * -k.drift_dir > 0.004):
			# Into the corner: hold the key (a full lean) to drift.
			_hold(KEY_LEFT if (curv > 0.0 if k.drift_dir == 0 else k.drift_dir < 0) else KEY_RIGHT)
		else:
			_steer(game)
		if k.drift_dir != 0 and k.drift_tier >= 1 and k.drift_time > 1.2 and k.surface == 0:
			_save("%s/%s_race.png" % [out, prefix])
			shot = true
			_hold(KEY_NONE)
			break
	if not shot:
		_save("%s/%s_race.png" % [out, prefix])
	# The drift meter mid-charge (tier 2, the knob lit), set on the rider's state with the game
	# frozen (time scale 0: no tick overwrites it), so the shot doesn't depend on catching a
	# drift: PREFIX_drift.
	var full: float = KartPhysics.TIER_SEC[2]
	Engine.time_scale = 0.0
	for f in 40:
		k.drift_dir = 1
		k.drift_charge = full * 0.62
		k.drift_tier = 2
		k.knob_boosting = true
		game._kart_hud.item_button.set_drift(1, k.drift_charge, 2, true, 1.0 / 60.0)
		await process_frame
	_save("%s/%s_drift.png" % [out, prefix])
	k.drift_dir = 0
	k.drift_charge = 0.0
	k.drift_tier = 0
	Engine.time_scale = 1.0
	# The HUDs' share of the draw calls.
	for state in [[true, true], [false, true], [false, false]]:
		game._kart_hud.visible = state[0]
		_director.hud.visible = state[1]
		for i in 12:
			await process_frame
		var total := 0.0
		for i in 120:
			await process_frame
			total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("CAPTURE draw_calls kart_hud=%s hud=%s: %.1f (mean of 120 frames)" % [state[0], state[1], total / 120.0])
	game._kart_hud.visible = true
	_director.hud.visible = true
	await _render_probe("race")
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
	await _render_probe("results")
	while game.flow != game.Flow.PODIUM and not game.has_ended():
		await process_frame
	await create_timer(2.6).timeout
	_save("%s/%s_podium.png" % [out, prefix])
	await _render_probe("podium")
	# Back to racing after the boards: the boards' viewports should be gone.
	game._board.hide_board()
	for i in 12:
		await process_frame
	await _render_probe("after boards")
	quit()


## Every viewport's measured render time (CPU), summed and per viewport, over 120 frames: the
## render's CPU side that the tablet pays for each one (the frame probes' render_cpu_ms).
func _render_probe(state: String) -> void:
	var vps: Array = [root]
	vps.append_array(root.find_children("*", "SubViewport", true, false))
	for vp in vps:
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	var last := {}
	for i in 6:
		await process_frame
		for vp in vps:
			last[vp] = RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
	var per := {}
	var total := 0.0
	var stale := 0.0  # what summing every viewport's value would add (an idle one repeats its last)
	var renders := 0
	for f in 120:
		await process_frame
		for vp in vps:
			if is_instance_valid(vp):
				var ms := RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
				var always: bool = vp == root or vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS
				if not always and ms == float(last.get(vp, -1.0)):
					stale += ms
					continue
				last[vp] = ms
				renders += 1
				var key := "%s/%s" % [vp.get_parent().name if vp.get_parent() else "-", vp.name]
				per[key] = per.get(key, 0.0) + ms
				total += ms
	var parts := []
	for key in per:
		if per[key] / 120.0 >= 0.005:
			parts.append("%s=%.3f" % [key, per[key] / 120.0])
	print("CAPTURE render %s: viewports=%d renders/frame=%.2f render_cpu_ms=%.3f (stale repeats not counted: +%.3f) (mean of 120 frames) %s" % [
		state, vps.size(), renders / 120.0, total / 120.0, stale / 120.0, " ".join(parts)])


## Holds one arrow key (KEY_NONE: none).
func _hold(want: Key) -> void:
	if want != _held:
		if _held != KEY_NONE:
			_key(_held, false)
		if want != KEY_NONE:
			_key(want, true)
		_held = want


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
