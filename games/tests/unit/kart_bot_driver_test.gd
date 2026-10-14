extends GdUnitTestSuite
## Kart Race's bots (#43, spec "Opponents"): the power profile, clean laps, power order, passing,
## hazards, drifting and item use. Bots drive through the same KartPhysics as the rider.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0
const FTP := 150.0


## A race of bots (kart 0 too), with optional items. `profiles[i]` drives kart i.
func _race(profiles: Array, track_def: KartTrackDef, laps := 3, seed_base := 1) -> Array:
	var race := KartRaceLogic.new()
	var racers := []
	for i in profiles.size():
		var r := {"racer_id": "r%d" % i, "weight": 1.0}
		if profiles[i].has("grid"):
			r["grid"] = profiles[i].grid
		racers.append(r)
	race.setup(KartTrackModel.new(track_def), racers, laps)
	var bots := []
	for i in profiles.size():
		bots.append(KartBotDriver.new(profiles[i], FTP, seed_base * 100 + i))
	race.start_countdown(0.0)
	return [race, bots]


func _step(race: KartRaceLogic, bots: Array, inputs: Array, items: KartItemLogic = null) -> void:
	for i in bots.size():
		inputs[i] = bots[i].think(race.karts[i], race, DT)
	race.step(DT, inputs)
	if items:
		items.step(DT, inputs)


func test_the_power_holds_its_share_and_wanders_slowly() -> void:
	var bot := KartBotDriver.new({"power_pct": 0.6}, FTP, 5)
	var lo := INF
	var hi := -INF
	var last := bot.power_at(0.0)
	for i in 3600:
		var p := bot.power_at(i * 1.0)
		lo = minf(lo, p)
		hi = maxf(hi, p)
		assert_float(absf(p - last)).is_less(0.5)  # watts per second: slow
		last = p
	assert_float(lo).is_greater_equal(90.0 * 0.96 - 0.01)
	assert_float(hi).is_less_equal(90.0 * 1.04 + 0.01)
	assert_float(hi - lo).is_greater(2.0)  # it does wander


func test_profiles_are_distinct_and_keep_the_given_power() -> void:
	var seen := {}
	for i in 7:
		var p := KartBotDriver.profile_for(i, 0.5 + i * 0.05)
		assert_float(float(p.power_pct)).is_equal_approx(0.5 + i * 0.05, 0.0001)
		seen[str([p.line_offset, p.drift_skill, p.item_skill, p.aggression])] = true
	assert_int(seen.size()).is_equal(7)


func test_with_equal_power_a_bot_laps_meadow_ring_without_wall_contact() -> void:
	var def := Fixtures.meadow()
	var clean := 0
	var runs := 50
	for run in runs:
		var profile := KartBotDriver.profile_for(run % 7, 1.0)
		profile.drift_skill = 1.0 if run % 2 == 0 else profile.drift_skill
		var setup := _race([profile], def, 3, run + 1)
		var race: KartRaceLogic = setup[0]
		var bots: Array = setup[1]
		var walls := [0]
		race.events.wall_bump.connect(func(_id: int, _s: float): walls[0] += 1)
		var inputs := [null]
		var k: KartState = race.karts[0]
		var touched := false
		var t := 0.0
		# From the grid over the line, then one full lap.
		while k.lap < 2 and t < 200.0:
			_step(race, bots, inputs)
			t += DT
		var start_t := t
		while k.lap < 3 and t < 400.0:
			_step(race, bots, inputs)
			t += DT
			if absf(k.d) > race.track.half_width(k.s) + race.track.verge - 0.05:
				touched = true
		assert_int(k.lap).override_failure_message("run %d never finished its lap" % run).is_equal(3)
		assert_float(t - start_t).is_less(90.0)
		if walls[0] == 0 and not touched:
			clean += 1
	assert_int(clean).override_failure_message("clean laps %d of %d" % [clean, runs]).is_greater_equal(runs - 1)  # 99%, rounded to whole laps


func test_bots_at_0_6_and_0_9_ftp_finish_in_power_order() -> void:
	# The stronger bot starts behind.
	var weak := KartBotDriver.profile_for(0, 0.6)
	weak["grid"] = 0
	var strong := KartBotDriver.profile_for(1, 0.9)
	strong["grid"] = 1
	var setup := _race([weak, strong], Fixtures.meadow(), 3)
	var race: KartRaceLogic = setup[0]
	var bots: Array = setup[1]
	var order := []
	race.events.race_finished.connect(func(o: Array): order.assign(o))
	var inputs := [null, null]
	var t := 0.0
	while order.is_empty() and t < 600.0:
		_step(race, bots, inputs)
		t += DT
	assert_array(order).is_equal([1, 0])
	assert_float(race.karts[1].finish_time).is_less(race.karts[0].finish_time - 10.0)


func test_a_full_field_finishes_roughly_in_power_order_without_wall_contact() -> void:
	var profiles := []
	for i in 8:
		var p := KartBotDriver.profile_for(i, 0.45 + 0.05 * i)
		p["grid"] = 7 - i  # the weakest on pole
		profiles.append(p)
	var setup := _race(profiles, Fixtures.meadow(), 3)
	var race: KartRaceLogic = setup[0]
	var bots: Array = setup[1]
	var walls := [0]
	race.events.wall_bump.connect(func(_id: int, _s: float): walls[0] += 1)
	var inputs := []
	inputs.resize(8)
	# Kart 0 is the weakest: the race ends when it finishes, so every bot gets there or close.
	var t := 0.0
	while race.phase != KartRaceLogic.Phase.FINISHED and t < 900.0:
		_step(race, bots, inputs)
		t += DT
	var order := race.order()
	assert_int(int(order[0])).is_greater_equal(6)  # one of the two strongest wins
	assert_int(int(order[7])).is_less_equal(1)  # one of the two weakest is last
	assert_int(walls[0]).is_less_equal(4)


func test_a_faster_bot_passes_a_slower_kart_in_its_lane() -> void:
	var fast := KartBotDriver.profile_for(6, 1.0)  # line offset 0
	fast["grid"] = 1
	var slow := KartBotDriver.profile_for(6, 0.5)
	slow["grid"] = 0
	var setup := _race([fast, slow], Fixtures.oval(600.0, 50.0, 6.0), 3)
	var race: KartRaceLogic = setup[0]
	var bots: Array = setup[1]
	# Both on the centre line, the slow one 25 m ahead and already up to speed.
	var track := race.track
	var put := func(k: KartState, s: float, speed: float):
		var p := track.project(track.position_at(s, 0.0), s)
		k.pos = p.position
		k.s = p.s
		k.d = p.d
		k.heading = track.yaw_at(p.s)
		k.speed = speed
		k.v_bike = speed / KartPhysics.SPEED_SCALE
	put.call(race.karts[0], 20.0, 14.0)
	put.call(race.karts[1], 45.0, 14.0)
	race.karts[0].lap = 1
	race.karts[1].lap = 1
	var bumps := [0]
	race.events.kart_bump.connect(func(_a: int, _b: int, _s: float): bumps[0] += 1)
	var inputs := [null, null]
	var passed_at := -1.0
	for i in roundi(30.0 / DT):
		_step(race, bots, inputs)
		if passed_at < 0.0 and race.progress(0) > race.progress(1) + 3.0:
			passed_at = i * DT
	assert_float(passed_at).is_greater(0.0)
	assert_int(bumps[0]).is_less_equal(2)


func test_a_bot_steers_round_goo_in_its_lane() -> void:
	var setup := _race([KartBotDriver.profile_for(6, 1.0)], Fixtures.oval(600.0, 50.0, 6.0), 3)
	var race: KartRaceLogic = setup[0]
	var bots: Array = setup[1]
	var items := KartItemLogic.new(race, 1)
	items.pods.clear()
	for b in bots:
		b.items = items
	var k: KartState = race.karts[0]
	var inputs := [null]
	for i in roundi(6.0 / DT):
		_step(race, bots, inputs, items)
	# Goo right on its line, 45 m ahead.
	var other := KartItemLogic.Goo.new()
	other.owner = -1
	other.s = race.track.wrap(k.s + 45.0)
	other.d = race.track.racing_line(other.s)
	other.pos = race.track.position_at(other.s, other.d)
	items.goos.append(other)
	var hits := [0]
	race.events.kart_hit.connect(func(_id: int, _by: int, _item: String): hits[0] += 1)
	for i in roundi(5.0 / DT):
		_step(race, bots, inputs, items)
	assert_int(hits[0]).is_equal(0)
	assert_bool(other.alive).is_true()


func test_a_skilled_bot_drifts_into_sharp_corners_and_an_unskilled_one_does_not() -> void:
	for skill in [1.0, 0.0]:
		var p := KartBotDriver.profile_for(6, 1.0)
		p.drift_skill = skill
		var setup := _race([p], Fixtures.oval(300.0, 30.0, 6.0), 3)
		var race: KartRaceLogic = setup[0]
		var bots: Array = setup[1]
		var inputs := [null]
		var held := 0.0
		var longest := 0.0
		for i in roundi(40.0 / DT):
			_step(race, bots, inputs)
			if absf(inputs[0].lean) >= 0.65:
				held += DT
				longest = maxf(longest, held)
			else:
				held = 0.0
		if skill > 0.5:
			assert_float(longest).override_failure_message("never held a drift lean").is_greater_equal(0.12)
		else:
			assert_float(longest).is_less(0.12)


func test_a_bot_uses_its_item_through_the_policy() -> void:
	var a := KartBotDriver.profile_for(0, 0.4)
	a["grid"] = 1
	var b := KartBotDriver.profile_for(6, 0.4)
	b["grid"] = 0
	var setup := _race([a, b], Fixtures.oval(600.0, 50.0, 6.0), 3)
	var race: KartRaceLogic = setup[0]
	var bots: Array = setup[1]
	var items := KartItemLogic.new(race, 1)
	items.pods.clear()
	for bot in bots:
		bot.items = items
	var used := []
	race.events.item_used.connect(func(id: int, item: String): used.append([id, item]))
	var inputs := [null, null]
	_step(race, bots, inputs, items)
	items.give(0, "drone")
	for i in roundi(4.0 / DT):
		_step(race, bots, inputs, items)
	assert_array(used).contains([[0, "drone"]])
	assert_float(race.karts[1].spin_time + (1.0 if race.karts[0].place == 1 else 0.0)).is_greater(0.0)


func test_a_spinning_bot_lets_go_of_the_controls() -> void:
	var setup := _race([KartBotDriver.profile_for(0, 1.0)], Fixtures.meadow(), 3)
	var race: KartRaceLogic = setup[0]
	var bots: Array = setup[1]
	var inputs := [null]
	for i in 300:
		_step(race, bots, inputs)
	race.physics.apply_spinout(race.karts[0])
	var inp: KartInput = bots[0].think(race.karts[0], race, DT)
	assert_float(inp.lean).is_equal(0.0)
	assert_bool(inp.use_item).is_false()
