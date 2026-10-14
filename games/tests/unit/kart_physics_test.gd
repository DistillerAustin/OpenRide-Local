extends GdUnitTestSuite
## Kart Race's physics core (#43): the virtual bike (power to speed), steering with the assist,
## surfaces, walls, spin-outs and kart-kart contacts. Drift, boosts and climbs are Phase 2.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0


func _kart(track: KartTrackModel, s := 0.0, d := 0.0) -> KartState:
	var k := KartState.new()
	var p := track.sample(s)
	k.s = s
	k.d = d
	k.pos = track.position_at(s, d)
	k.heading = atan2(-p.tangent.x, -p.tangent.z)
	return k


func _in(power := 150.0, lean := 0.0) -> KartInput:
	var inp := KartInput.new()
	inp.power_w = power
	inp.cadence = 85.0
	inp.lean = lean
	return inp


func _run(physics: KartPhysics, k: KartState, inp: KartInput, track: KartTrackModel, seconds: float) -> void:
	for i in roundi(seconds / DT):
		physics.step(k, inp, track, DT)


func test_steady_bike_speed_solves_the_power_balance() -> void:
	# No drivetrain loss: 150 = 4.17·v + 0.192·v³.
	assert_float(KartPhysics.steady_bike_speed(150.0, 0.0)).is_equal_approx(8.43, 0.05)
	assert_float(KartPhysics.steady_bike_speed(200.0, 0.0)).is_greater(KartPhysics.steady_bike_speed(150.0, 0.0))
	assert_float(KartPhysics.steady_bike_speed(100.0, 0.0)).is_less(KartPhysics.steady_bike_speed(150.0, 0.0))
	assert_float(KartPhysics.steady_bike_speed(150.0, 0.05)).is_less(KartPhysics.steady_bike_speed(150.0, 0.0))
	assert_float(KartPhysics.steady_bike_speed(150.0, -0.03)).is_greater(KartPhysics.steady_bike_speed(150.0, 0.0))
	assert_float(KartPhysics.steady_bike_speed(150.0, 0.0, 1.0)).is_greater(KartPhysics.steady_bike_speed(150.0, 0.0))
	assert_float(KartPhysics.steady_bike_speed(0.0, 0.0)).is_equal(0.0)


func test_from_rest_the_kart_reaches_its_steady_speed_quickly() -> void:
	var track := KartTrackModel.new(Fixtures.oval())
	var physics := KartPhysics.new()
	var k := _kart(track)
	var target := KartPhysics.steady_bike_speed(150.0, 0.0) * KartPhysics.SPEED_SCALE
	var t := 0.0
	while k.speed < 0.95 * target and t < 20.0:
		physics.step(k, _in(), track, DT)
		t += DT
	assert_float(t).is_less(12.0)
	# And settles there, not above.
	_run(physics, k, _in(), track, 20.0)
	assert_float(k.speed).is_equal_approx(target, 0.03 * target)


func test_without_pedalling_the_kart_coasts_to_a_stop_and_never_reverses() -> void:
	var track := KartTrackModel.new(Fixtures.oval())
	var physics := KartPhysics.new()
	var k := _kart(track)
	_run(physics, k, _in(), track, 15.0)
	assert_float(k.speed).is_greater(15.0)
	var t := 0.0
	var last_s := k.s
	while t < 25.0:
		physics.step(k, _in(0.0), track, DT)
		assert_float(k.speed).is_greater_equal(0.0)
		assert_float(track.delta(last_s, k.s)).is_greater_equal(-0.001)
		last_s = k.s
		t += DT
		if k.speed < 0.5:
			break
	assert_float(k.speed).is_less(0.5)


func test_a_full_lean_turns_the_kart() -> void:
	var track := KartTrackModel.new(Fixtures.oval(400.0))
	var physics := KartPhysics.new()
	physics.assist = 0.0
	var k := _kart(track, track.length - 150.0)
	_run(physics, k, _in(), track, 6.0)
	var before := k.heading
	_run(physics, k, _in(150.0, 1.0), track, 0.5)
	# Right is clockwise seen from above: the yaw falls.
	assert_float(angle_difference(before, k.heading)).is_less(-0.4)
	assert_float(k.steer).is_greater(0.5)
	var right := k.heading
	_run(physics, k, _in(150.0, -1.0), track, 0.5)
	assert_float(angle_difference(right, k.heading)).is_greater(0.4)


func test_the_assist_follows_a_corner_with_no_lean() -> void:
	var track := KartTrackModel.new(Fixtures.circle(40.0, 24, 6.0))
	var physics := KartPhysics.new()
	physics.assist = 1.0
	var k := _kart(track)
	for i in roundi(10.0 / DT):
		physics.step(k, _in(), track, DT)
		assert_float(absf(k.d)).is_less(track.half_width(k.s))
	assert_float(k.speed).is_greater(15.0)
	# With no assist and no lean, the kart runs wide into the wall instead.
	physics.assist = 0.0
	var loose := _kart(track)
	var hit_wall := false
	for i in roundi(10.0 / DT):
		physics.step(loose, _in(), track, DT)
		hit_wall = hit_wall or absf(loose.d) > track.half_width(loose.s) + 1.0
	assert_bool(hit_wall).is_true()


func test_a_light_lean_moves_the_kart_across_and_holds_the_line_when_released() -> void:
	var track := KartTrackModel.new(Fixtures.oval(400.0))
	var physics := KartPhysics.new()
	var k := _kart(track, track.length - 150.0)
	_run(physics, k, _in(), track, 5.0)
	var d0 := k.d
	_run(physics, k, _in(150.0, 0.5), track, 1.0)
	assert_float(k.d).is_greater(d0 + 1.0)
	_run(physics, k, _in(), track, 2.0)
	var held := k.d
	_run(physics, k, _in(), track, 2.0)
	assert_float(k.d).is_equal_approx(held, 0.5)
	# A small lean inside the dead zone does nothing.
	var still := k.d
	_run(physics, k, _in(150.0, KartPhysics.DEAD_ZONE * 0.5), track, 2.0)
	assert_float(k.d).is_equal_approx(still, 0.2)


func test_off_road_caps_the_speed() -> void:
	var track := KartTrackModel.new(Fixtures.oval(600.0))
	var physics := KartPhysics.new()
	var on_road := _kart(track, track.length - 250.0)
	var off_road := _kart(track, track.length - 250.0, track.half_width(0.0) + 2.0)
	for i in roundi(15.0 / DT):
		physics.step(on_road, _in(), track, DT)
		physics.step(off_road, _in(), track, DT)
	assert_int(off_road.surface).is_equal(KartTrackModel.Surface.OFFROAD)
	assert_int(on_road.surface).is_equal(KartTrackModel.Surface.ROAD)
	assert_float(off_road.speed).is_less_equal(0.55 * on_road.speed + 0.05)
	assert_float(off_road.speed).is_greater(0.25 * on_road.speed)


func test_a_wall_keeps_the_kart_on_the_track_and_costs_speed() -> void:
	var track := KartTrackModel.new(Fixtures.oval(600.0))
	var physics := KartPhysics.new()
	physics.assist = 0.0
	var events := KartRaceEvents.new()
	physics.events = events
	var bumps: Array = []
	events.wall_bump.connect(func(id: int, strength: float): bumps.append([id, strength]))
	var k := _kart(track, track.length - 250.0)
	_run(physics, k, _in(), track, 10.0)
	var fast := k.speed
	# Turn hard toward the right-hand wall.
	k.heading -= 0.6
	var slowest := fast
	var reach := track.half_width(0.0) + track.verge
	for i in roundi(3.0 / DT):
		physics.step(k, _in(), track, DT)
		assert_float(absf(k.d)).is_less_equal(reach + 0.001)
		slowest = minf(slowest, k.speed)
	assert_float(slowest).is_less(0.85 * fast)
	assert_bool(bumps.is_empty()).is_false()
	assert_float(float(bumps[0][1])).is_between(0.05, 1.0)
	# Grinding along the wall doesn't bump every tick.
	assert_int(bumps.size()).is_less(4)


func test_a_spin_out_takes_control_and_speed_unless_a_shield_blocks_it() -> void:
	var track := KartTrackModel.new(Fixtures.oval())
	var physics := KartPhysics.new()
	var k := _kart(track)
	_run(physics, k, _in(), track, 10.0)
	k.shield_time = 8.0
	assert_bool(physics.apply_spinout(k)).is_false()
	assert_float(k.spin_time).is_equal(0.0)
	assert_float(k.shield_time).is_equal(0.0)
	var fast := k.speed
	assert_bool(physics.apply_spinout(k)).is_true()
	assert_float(k.spin_time).is_greater(0.0)
	assert_float(k.speed).is_equal_approx(0.4 * fast, 0.01)
	# No steering while spinning, and it wears off.
	var heading := k.heading
	_run(physics, k, _in(150.0, 1.0), track, 0.5)
	assert_float(absf(angle_difference(heading, k.heading))).is_less(0.05)
	_run(physics, k, _in(), track, 1.0)
	assert_float(k.spin_time).is_equal(0.0)


func test_a_boost_raises_the_speed_for_its_time() -> void:
	var track := KartTrackModel.new(Fixtures.oval(800.0))
	var physics := KartPhysics.new()
	var k := _kart(track, track.length - 350.0)
	_run(physics, k, _in(), track, 15.0)
	var cruise := k.speed
	physics.apply_boost(k, 1.0)
	_run(physics, k, _in(), track, 0.9)
	assert_float(k.speed).is_greater(1.2 * cruise)
	_run(physics, k, _in(), track, 4.0)
	assert_float(k.boost_time).is_equal(0.0)
	assert_float(k.speed).is_equal_approx(cruise, 0.05 * cruise)


func test_contacts_push_karts_apart_by_weight() -> void:
	var heavy := KartState.new()
	heavy.id = 0
	heavy.weight = 1.15
	heavy.pos = Vector3(0, 0, 0)
	var light := KartState.new()
	light.id = 1
	light.weight = 0.85
	light.pos = Vector3(1.0, 0, 0)
	var far := KartState.new()
	far.id = 2
	far.pos = Vector3(30.0, 0, 0)
	var hits := KartPhysics.resolve_contacts([heavy, light, far])
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0][0])).is_equal(0)
	assert_int(int(hits[0][1])).is_equal(1)
	assert_float(float(hits[0][2])).is_greater(0.0)
	var gap := Vector2(light.pos.x - heavy.pos.x, light.pos.z - heavy.pos.z).length()
	assert_float(gap).is_greater_equal(2.0 * KartPhysics.KART_RADIUS - 0.001)
	# The light kart moved further.
	assert_float(light.pos.x - 1.0).is_greater(-heavy.pos.x)
	assert_array(KartPhysics.resolve_contacts([heavy, light, far])).is_empty()


func test_the_simulation_is_deterministic() -> void:
	var track := KartTrackModel.new(Fixtures.meadow())
	var runs: Array[KartState] = []
	for r in 2:
		var physics := KartPhysics.new()
		var k := _kart(track)
		for i in 600:
			physics.step(k, _in(120.0 + 60.0 * sin(i * 0.05), 0.8 * sin(i * 0.03)), track, DT)
		runs.append(k)
	assert_vector(runs[0].pos).is_equal(runs[1].pos)
	assert_float(runs[0].heading).is_equal(runs[1].heading)
	assert_float(runs[0].speed).is_equal(runs[1].speed)
	assert_float(runs[0].s).is_equal(runs[1].s)


func test_the_kart_follows_the_road_surface_up_a_climb() -> void:
	var track := KartTrackModel.new(Fixtures.meadow())
	var physics := KartPhysics.new()
	var k := _kart(track, 440.0)
	var flat := KartPhysics.steady_bike_speed(150.0, 0.0) * KartPhysics.SPEED_SCALE
	_run(physics, k, _in(), track, 8.0)
	assert_float(k.pos.y).is_equal_approx(track.position_at(k.s, k.d).y, 0.05)
	assert_float(k.pos.y).is_greater(1.0)
	# Uphill is slower than the flat.
	assert_float(k.speed).is_less(0.9 * flat)
