extends GdUnitTestSuite
## Kart Race's race logic (#43): the grid, the countdown, laps (forward wraps only), positions,
## the finish and its events.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0


func _racers(n: int) -> Array:
	var racers := []
	for i in n:
		racers.append({"racer_id": "r%d" % i, "weight": 1.0})
	return racers


func _race(def: KartTrackDef, n := 8, laps := 3) -> KartRaceLogic:
	var race := KartRaceLogic.new()
	race.setup(KartTrackModel.new(def), _racers(n), laps)
	return race


func _inputs(n: int, power := 150.0, lean := 0.0) -> Array:
	var inputs := []
	for i in n:
		var inp := KartInput.new()
		inp.power_w = power
		inp.cadence = 85.0
		inp.lean = lean
		inputs.append(inp)
	return inputs


func _start(race: KartRaceLogic) -> void:
	race.start_countdown(0.0)
	race.step(DT, _inputs(race.karts.size()))


func _run(race: KartRaceLogic, seconds: float, inputs: Array) -> void:
	for i in roundi(seconds / DT):
		race.step(DT, inputs)


func test_the_grid_lines_up_behind_the_start_line() -> void:
	var race := _race(Fixtures.meadow())
	assert_int(race.karts.size()).is_equal(8)
	assert_int(race.phase).is_equal(KartRaceLogic.Phase.GRID)
	for k: KartState in race.karts:
		assert_int(k.lap).is_equal(0)
		# Behind the line, on the road, facing the way round.
		assert_float(race.track.delta(0.0, k.s)).is_between(-60.0, -2.0)
		assert_float(absf(k.d)).is_less(race.track.half_width(k.s) - 1.0)
		assert_float(absf(angle_difference(race.track.yaw_at(k.s), k.heading))).is_less(0.01)
	# The rider starts at the back.
	assert_int(race.place_of(0)).is_equal(8)
	assert_array(race.order()).has_size(8)
	# No two karts overlap.
	assert_array(KartPhysics.resolve_contacts(race.karts)).is_empty()


func test_inputs_are_ignored_during_the_countdown() -> void:
	var race := _race(Fixtures.meadow())
	var started := [0]
	race.events.race_started.connect(func(): started[0] += 1)
	var grid := race.karts.map(func(k): return k.pos)
	race.start_countdown(3.0)
	assert_int(race.phase).is_equal(KartRaceLogic.Phase.COUNTDOWN)
	_run(race, 2.9, _inputs(8, 400.0, 1.0))
	for k: KartState in race.karts:
		assert_vector(k.pos).is_equal(grid[k.id])
		assert_float(k.v_bike).is_equal(0.0)
	assert_int(started[0]).is_equal(0)
	_run(race, 0.2, _inputs(8, 400.0, 0.0))
	assert_int(race.phase).is_equal(KartRaceLogic.Phase.RACING)
	assert_int(started[0]).is_equal(1)
	_run(race, 2.0, _inputs(8, 200.0))
	assert_float(race.karts[0].speed).is_greater(1.0)
	assert_int(started[0]).is_equal(1)


func test_laps_count_only_on_forward_wraps() -> void:
	var race := _race(Fixtures.circle(60.0), 1, 5)
	race.physics.assist = 0.0
	var laps: Array = []
	race.events.lap_completed.connect(func(id: int, lap: int, t: float): laps.append([id, lap, t]))
	_start(race)
	var k: KartState = race.karts[0]
	# Drive round with a gentle left lean: across the line (lap 1), then once round (lap 2).
	var inputs := _inputs(1, 150.0, 0.0)
	race.physics.assist = 1.0
	while k.lap < 2:
		race.step(DT, inputs)
	assert_int(laps.size()).is_equal(1)
	assert_int(int(laps[0][1])).is_equal(1)
	assert_float(float(laps[0][2])).is_between(10.0, 60.0)
	# Turn round and drive back over the line: the lap goes back, with no event.
	_run(race, 3.0, inputs)
	var before := race.progress(0)
	k.pos = race.track.position_at(5.0, 0.0)
	k.s = 5.0
	k.heading = race.track.yaw_at(5.0) + PI
	k.speed = 10.0
	race.physics.assist = 0.0
	var back_progress := race.progress(0)
	while race.track.delta(0.0, k.s) > -5.0:
		race.step(DT, _inputs(1, 60.0, 0.0))
	assert_int(k.lap).is_equal(1)
	assert_float(race.progress(0)).is_less(back_progress)
	assert_float(race.progress(0)).is_less(before)
	# And forward over it again: back to lap 2, still no new event.
	k.heading = race.track.yaw_at(k.s)
	race.physics.assist = 1.0
	while k.lap < 2:
		race.step(DT, inputs)
	_run(race, 1.0, inputs)
	assert_int(laps.size()).is_equal(1)
	# A real lap after that does count.
	while k.lap < 3:
		race.step(DT, inputs)
	assert_int(laps.size()).is_equal(2)
	assert_int(int(laps[1][1])).is_equal(2)


func test_positions_follow_progress_and_change_once_per_pass() -> void:
	var race := _race(Fixtures.oval(500.0), 2, 3)
	var changes: Array = []
	race.events.position_changed.connect(func(id: int, old: int, now: int): changes.append([id, old, now]))
	_start(race)
	assert_int(race.place_of(1)).is_equal(1)
	assert_int(race.place_of(0)).is_equal(2)
	# The rider pushes 260 W, the bot 90 W: one clean pass.
	var inputs := _inputs(2, 90.0)
	inputs[0].power_w = 260.0
	_run(race, 40.0, inputs)
	assert_float(race.progress(0)).is_greater(race.progress(1))
	assert_int(race.place_of(0)).is_equal(1)
	assert_int(race.place_of(1)).is_equal(2)
	var rider_changes := changes.filter(func(c): return c[0] == 0)
	var bot_changes := changes.filter(func(c): return c[0] == 1)
	assert_int(rider_changes.size()).is_equal(1)
	assert_array(rider_changes[0]).is_equal([0, 2, 1])
	assert_int(bot_changes.size()).is_equal(1)
	assert_array(bot_changes[0]).is_equal([1, 1, 2])
	assert_array(race.order()).is_equal([0, 1])


func test_the_race_ends_when_the_rider_finishes_and_the_order_is_final() -> void:
	var race := _race(Fixtures.circle(60.0), 3, 2)
	var finished: Array = []
	var ended: Array = []
	race.events.kart_finished.connect(func(id: int, place: int, t: float): finished.append([id, place, t]))
	race.events.race_finished.connect(func(order: Array): ended.append(order))
	_start(race)
	# Two strong bots, a slow rider: the bots finish first and the race goes on for the rider.
	var inputs := _inputs(3, 300.0)
	inputs[0].power_w = 90.0
	var t := 0.0
	while ended.is_empty() and t < 300.0:
		race.step(DT, inputs)
		t += DT
		if finished.size() == 2:
			assert_int(race.phase).is_equal(KartRaceLogic.Phase.RACING)
	assert_int(ended.size()).is_equal(1)
	assert_int(race.phase).is_equal(KartRaceLogic.Phase.FINISHED)
	assert_int(finished.size()).is_equal(3)
	assert_int(int(finished[2][0])).is_equal(0)
	assert_int(int(finished[2][1])).is_equal(3)
	var order: Array = ended[0]
	assert_int(int(order[2])).is_equal(0)
	assert_bool(race.karts.all(func(k): return k.finished)).is_true()
	# Final: the karts drive on, nothing changes, nothing fires again.
	_run(race, 20.0, inputs)
	assert_int(ended.size()).is_equal(1)
	assert_int(finished.size()).is_equal(3)
	assert_array(race.order()).is_equal(order)
	for k: KartState in race.karts:
		assert_int(race.place_of(k.id)).is_equal(order.find(k.id) + 1)


func test_bots_still_running_are_placed_by_progress_with_projected_times() -> void:
	var race := _race(Fixtures.circle(60.0), 4, 2)
	var ended: Array = []
	race.events.race_finished.connect(func(order: Array): ended.append(order))
	_start(race)
	var inputs := _inputs(4, 80.0)
	inputs[0].power_w = 300.0
	inputs[3].power_w = 120.0
	while ended.is_empty():
		race.step(DT, inputs)
	var rider: KartState = race.karts[0]
	assert_int(rider.place).is_equal(1)
	assert_int(int(ended[0][0])).is_equal(0)
	# The strongest bot is next: it got furthest.
	assert_int(int(ended[0][1])).is_equal(3)
	var last_time := rider.finish_time
	for id in ended[0].slice(1):
		var k: KartState = race.karts[id]
		assert_bool(k.finished).is_true()
		assert_float(k.finish_time).is_greater(last_time)
		# Projected karts are spread by believable gaps, never the 0.01 s steps that read as fake.
		assert_float(k.finish_time - last_time).is_greater_equal(0.25)
		last_time = k.finish_time


func test_a_projected_finish_uses_the_race_pace_not_a_momentary_stall() -> void:
	var race := _race(Fixtures.circle(60.0), 2, 2)
	var ended: Array = []
	race.events.race_finished.connect(func(order: Array): ended.append(order))
	_start(race)
	var inputs := _inputs(2, 80.0)
	inputs[0].power_w = 300.0
	inputs[1].power_w = 200.0
	while ended.is_empty():
		# The bot stalls (a spin, a wall) just as the rider crosses the line.
		if race.karts[0].lap == race.laps and race.karts[0].s > race.track.length - 3.0:
			race.karts[1].speed = 0.5
		race.step(DT, inputs)
	var bot: KartState = race.karts[1]
	assert_float(bot.finish_time).is_greater(race.time)  # it was still racing: projected
	var left := (race.laps + 1) * race.track.length - race.progress(1)
	# Timed at its race average (about its cruising speed), not at 0.5 m/s or the 3 m/s floor.
	assert_float(bot.finish_time - race.time).is_less(left / 3.0 * 0.6)


func test_hugging_a_wall_never_escapes_the_track_or_breaks_laps() -> void:
	var race := _race(Fixtures.meadow(), 1, 5)
	var laps: Array = []
	race.events.lap_completed.connect(func(id: int, lap: int, t: float): laps.append(lap))
	_start(race)
	var k: KartState = race.karts[0]
	var hug := _inputs(1, 180.0, 1.0)
	var last := race.progress(0)
	var distance := 0.0
	for i in roundi(240.0 / DT):
		var prev_s := k.s
		race.step(DT, hug)
		assert_float(absf(k.d)).is_less_equal(race.track.half_width(k.s) + race.track.verge + 0.001)
		distance += race.track.delta(prev_s, k.s)
		# Progress never jumps.
		assert_float(absf(race.progress(0) - last)).is_less(5.0)
		last = race.progress(0)
	# Every lap counted exactly once, in order, matching the distance driven.
	assert_float(distance).is_greater(race.track.length * 1.2)
	assert_int(k.lap).is_equal(floori(race.progress(0) / race.track.length))
	assert_int(laps.size()).is_equal(k.lap - 1)
	for i in laps.size():
		assert_int(int(laps[i])).is_equal(i + 1)


func test_progress_is_monotonic_driving_forward() -> void:
	var race := _race(Fixtures.meadow(), 8, 3)
	_start(race)
	var last := []
	for k in race.karts:
		last.append(race.progress(k.id))
	var inputs := _inputs(8, 150.0)
	for i in roundi(60.0 / DT):
		race.step(DT, inputs)
		for k: KartState in race.karts:
			# (A bump from behind may nudge a kart back a little.)
			assert_float(race.progress(k.id)).is_greater_equal(last[k.id] - 0.5)
			last[k.id] = race.progress(k.id)


func test_order_into_refills_the_callers_array_with_the_race_order() -> void:
	# Review of PR #58: the HUD asked for order() every frame, a new Array each time.
	var race := _race(Fixtures.oval(400.0, 40.0, 6.0))
	race.start_countdown(0.0)
	var inputs := _inputs(8, 200.0)
	for i in 120:
		race.step(DT, inputs)
	var buffer := [99, 98]
	race.order_into(buffer)
	assert_array(buffer).is_equal(race.order())
	race.step(DT, inputs)
	race.order_into(buffer)
	assert_array(buffer).is_equal(race.order())
	assert_int(buffer.size()).is_equal(8)
