extends SceneTree
## Headless playthrough of Kart Race (#43) with the keyboard simulator:
##   $GODOT_BIN --headless --path games -s res://tests/sim_kart_check.gd
## A 5-minute local Just Ride at 4× speed: the intro card and calibration, then a Grand Prix
## driven with the keys (cadence up, the arrows steering toward the racing line using the track
## model). It must end on the final race's finish line (the game ends the segment, before the
## 1.5× hard stop), and the summary must appear.

const SPEED := 4.0
const DURATION := 300
const TIMEOUT_SEC := 240.0  ## real seconds

var _failures: Array[String] = []
var _session: Node
var _director: Node  # untyped: a -s script compiles before the autoloads exist
var _ended_on := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = SPEED
	_session._local.start({"kind": "just_ride", "plan_id": "just-ride:kart_race:minutes:5", "difficulty": "standard",
		"total_sec": DURATION + 10, "segments": [{"game_id": "kart_race", "role": "free", "duration_sec": DURATION}]})
	await _frames(3)
	_check(_director.intro_card.visible, "the intro card shows")
	_check(_director.calibration.visible, "calibration runs for the camera game")
	_check(_session.tracker_mode == "lean_stand", "the tracker mode is lean_stand (%s)" % _session.tracker_mode)
	_check(str(_session.segment.end_mode) == "game", "a timed Kart Race ends on its own terms (%s)" % _session.segment.end_mode)
	var game: Node = _director.game
	_check(game != null and game.game_id == "kart_race", "Kart Race is loaded")
	_check(game.get("race") != null and game.race.karts.size() == 8, "the grid has eight karts")
	game.ended.connect(func():
		_ended_on = {
			"race_phase": game.race.phase,
			"rider_finished": game.race.karts[0].finished,
			"final": bool(game.current.get("is_final", false)),
			"played": game.played_sec,
			"laps": game.race.laps,
			"place": game.race.karts[0].place,
		})

	await _until(func(): return _director.phase_name() == "PLAYING", 30.0)
	_check(_director.phase_name() == "PLAYING", "gameplay starts")
	# Pedal up: about 100 rpm at 35% resistance (~190 W in the simulator).
	_key(KEY_EQUAL, true)
	await create_timer(0.5).timeout
	_key(KEY_EQUAL, false)
	var input_bus := root.get_node("InputBus")
	_check(input_bus.cadence > 90.0, "cadence is up (%d rpm)" % input_bus.cadence)

	var results: Array = _session._local._results
	var start := Time.get_ticks_msec()
	var held := KEY_NONE
	var max_off := 0.0
	var wall_frames := 0
	var session_phase := ""
	while results.is_empty() and Time.get_ticks_msec() - start < TIMEOUT_SEC * 1000.0:
		session_phase = _session._local._phase  # the local Kotlin stand-in, until the result lands
		await process_frame
		if _director.game == null or _director.game.get("race") == null:
			continue
		var race = _director.game.race
		var k = race.karts[0]
		max_off = maxf(max_off, absf(k.d) - race.track.half_width(k.s))
		if k.surface == 3:
			wall_frames += 1
		var aim: float = race.track.racing_line(k.s + 12.0) * 0.6
		var want := KEY_NONE
		if aim - k.d > 0.7:
			want = KEY_RIGHT
		elif aim - k.d < -0.7:
			want = KEY_LEFT
		if want != held:
			if held != KEY_NONE:
				_key(held, false)
			if want != KEY_NONE:
				_key(want, true)
			held = want
	if held != KEY_NONE:
		_key(held, false)

	_check(results.size() == 1, "the Grand Prix reported a result (%s)" % [results])
	_check(not _ended_on.is_empty(), "the game ended the segment itself")
	if not _ended_on.is_empty():
		_check(_ended_on.final, "the race that ended it was the final race")
		_check(_ended_on.rider_finished and _ended_on.race_phase == 3, "it ended on the finish line (%s)" % [_ended_on])
		_check(session_phase == "playing", "before the hard stop (%s)" % session_phase)
		_check(_ended_on.played < DURATION * 1.5, "inside 1.5 × the length (%.0f s)" % _ended_on.played)
		print("SIM kart: ended after %.0f s of play, %d laps, place %d" % [_ended_on.played, _ended_on.laps, _ended_on.place])
	if results.size() == 1:
		var r: Dictionary = results[0]
		_check(r.game_id == "kart_race" and not r.skipped, "the result is Kart Race's")
		_check(float(r.score) > 0.0, "it scored (%s)" % r.score)
		for key in ["position", "races", "wins", "podiums", "best_lap", "race_time", "boosts", "items_hit", "avg_power", "ghost_trace", "effort_avg"]:
			_check(r.stats.has(key), "stats.%s is there" % key)
		_check(int(r.stats.get("races", 0)) == 1, "one race in five minutes (%s)" % r.stats.get("races"))
		print("SIM kart: score %d, stars %d, stats %s" % [r.score, r.stars, JSON.stringify(r.stats).left(300)])
	_check(max_off < KartTrackModel.KERB_WIDTH + 2.0, "the keys kept the kart near the road (%.1f m past the edge)" % max_off)
	await _frames(3)
	_check(not _session.active, "the session finished")
	_check(_director.summary_screen.visible, "the summary shows")

	Engine.time_scale = 1.0
	if _failures.is_empty():
		print("PASS sim kart")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL ", f)
		quit(1)


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _until(condition: Callable, timeout_sec: float) -> void:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < timeout_sec * 1000.0:
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(condition: bool, what: String) -> void:
	if not condition:
		_failures.append(what)
