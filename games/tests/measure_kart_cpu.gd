extends SceneTree
## Where Kart Race's main-thread CPU goes (#43, the tablet is CPU-bound with the face tracker
## running): plays a local race headless and times each part of a frame, per 60 Hz tick and per
## frame, over SECONDS of racing:
##   $GODOT_BIN --headless --path games -s res://tests/measure_kart_cpu.gd [-- --seconds=60]
## Prints `MEASURE kart_cpu part=… us_per_frame=…`. The desktop is several times faster than the
## tablet: read the shares, not the absolute numbers.

const DT := 1.0 / 60.0
var _t := {}


func _initialize() -> void:
	_run.call_deferred()


func _time(part: String, c: Callable) -> Variant:
	var t0 := Time.get_ticks_usec()
	var r: Variant = c.call()
	_t[part] = _t.get(part, 0) + Time.get_ticks_usec() - t0
	return r


func _run() -> void:
	await process_frame
	var seconds := 60.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.get_slice("=", 1))
	var game = load("res://games/kart_race/KartRace.tscn").instantiate()
	game.hud = load("res://framework/hud/Hud.gd").new()
	root.add_child(game.hud)
	root.add_child(game)
	game.prepare({"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 1200,
		"end_mode": "game", "seed": 7, "effort": true, "params": {"ftp_watts": 150}})
	var inp = load("res://games/kart_race/logic/KartInput.gd").new()
	inp.power_w = 150.0
	inp.cadence = 85.0
	game.test_input = inp
	game.start()
	# To the green light.
	while game.flow != game.Flow.RACING:
		game._on_frame(DT)
	var frames := roundi(seconds * 60.0)
	for f in frames:
		inp.lean = sin(f * 0.01) * 0.3
		var t0 := Time.get_ticks_usec()
		game.sim_time += DT
		var inputs: Array = _time("bots+inputs", func(): return game._inputs(DT))
		# race.step, part by part (KartRaceLogic.step while racing).
		var race = game.race
		race.time += DT
		_time("race.drafts", func(): KartPhysics.update_drafts(race.karts))
		_time("race.physics", func():
			for k in race.karts:
				var prev_s: float = k.s
				race.physics.step(k, race._input_of(k, inputs), race.track, DT)
				if not k.finished:
					race._check_line(k, prev_s, DT))
		_time("race.contacts", func():
			for hit in KartPhysics.resolve_contacts(race.karts):
				race.events.kart_bump.emit(int(hit[0]), int(hit[1]), float(hit[2])))
		_time("race.places", func(): race._update_places())
		_time("items.step", func(): game.items.step(DT, inputs))
		_time("scoring.step", func(): game.scoring.step(DT, inputs[0].power_w))
		_time("sync_views (views, camera, item views, fx, audio, draft)", func(): game._sync_views(DT))
		_time("hud", func(): game._update_hud(DT))
		_t["frame"] = _t.get("frame", 0) + Time.get_ticks_usec() - t0
		await process_frame  # the engine's own _process callbacks (bakes, board, KartWorld spinners)
		if game.flow != game.Flow.RACING:
			break
	var parts := _t.keys()
	parts.sort_custom(func(a, b): return _t[a] > _t[b])
	for p in parts:
		print("MEASURE kart_cpu part=%s us_per_frame=%.0f" % [p, float(_t[p]) / frames])
	quit()
