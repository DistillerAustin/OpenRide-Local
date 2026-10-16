extends SceneTree
## Where Kart Race's main-thread CPU goes (#43, the tablet is CPU-bound with the face tracker
## running): plays a local race headless and times each part of a frame, per 60 Hz tick and per
## frame, over SECONDS of racing:
##   $GODOT_BIN --headless --path games -s res://tests/measure_kart_cpu.gd [-- --seconds=60]
## Prints `MEASURE kart_cpu part=… us_per_frame=…` per 60 Hz frame (the logic parts run at the
## game's TICK, 30 Hz, so they're averaged over the frames between). The desktop is 15-25 times
## faster than the tablet: read the shares, not the absolute numbers.

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
	game.set_process(false)  # this script steps the frame (Game._process would step it a second time)
	# To the green light.
	while game.flow != game.Flow.RACING:
		game._on_frame(DT)
	var frames := roundi(seconds * 60.0)
	var measured := 0
	var tick: float = game.TICK
	var acc := 0.0
	for f in frames:
		inp.lean = sin(f * 0.01) * 0.3
		var t0 := Time.get_ticks_usec()
		var race = game.race
		# KartRace._frame: the logic at its fixed tick, part by part (KartRaceLogic.step racing).
		acc += DT
		while acc >= tick:
			acc -= tick
			game.sim_time += tick
			var inputs: Array = _time("bots+inputs", func(): return game._inputs(tick))
			race.time += tick
			_time("race.snap", func():
				for k in race.karts:
					k.snap())
			_time("race.drafts", func(): KartPhysics.update_drafts(race.karts))
			_time("race.physics", func():
				for k in race.karts:
					var prev_s: float = k.s
					race.physics.step(k, race._input_of(k, inputs), race.track, tick)
					if not k.finished:
						race._check_line(k, prev_s, tick))
			_time("race.contacts", func():
				for hit in KartPhysics.resolve_contacts(race.karts):
					race.events.kart_bump.emit(int(hit[0]), int(hit[1]), float(hit[2])))
			_time("race.places", func(): race._update_places())
			_time("items.step", func(): game.items.step(tick, inputs))
			_time("scoring.step", func(): game.scoring.step(tick, inputs[0].power_w))
		game._acc = acc
		# _sync_views, part by part (KartRace._sync_views while racing), every frame.
		var alpha := acc / tick
		_time("views.draw_into", func():
			for i in race.karts.size():
				race.karts[i].draw_into(game._draw[i], alpha))
		_time("views.sync", func():
			for i in game.views.size():
				game.views[i].sync(game._draw[i], DT))
		_time("camera", func(): game.camera.follow(game._draw[0], DT))
		_time("views.cull", func(): game._cull_views())
		_time("item_views", func():
			game._item_views.alpha = alpha
			game._item_views.sync(DT))
		_time("fx", func(): game._fx.step(race, DT))
		_time("audio", func(): game._audio.step(race, game.Flow.keys()[game.flow], DT))
		_time("draft_screen", func(): game._sync_screen_fx())
		_time("hud", func(): game._update_hud(DT))
		_t["frame"] = _t.get("frame", 0) + Time.get_ticks_usec() - t0
		measured += 1
		# Let the engine run a frame (the other nodes' _process: HUD widgets, bakes) once a second
		# only: idling between frames lets the desktop clock the thread down, which swamps the
		# numbers. Back-to-back frames keep it at a steady clock.
		if f % 60 == 59:
			await process_frame
		if game.flow != game.Flow.RACING:
			break
	frames = maxi(measured, 1)
	print("MEASURE kart_cpu frames=%d race_time=%.1f" % [frames, game.race.time])
	var parts := _t.keys()
	parts.sort_custom(func(a, b): return _t[a] > _t[b])
	for p in parts:
		print("MEASURE kart_cpu part=%s us_per_frame=%.0f" % [p, float(_t[p]) / frames])
	quit()
