extends GdUnitTestSuite
## Kart Race's cup (#43, Task B1): four original tracks, each with its own theme, every one
## drivable both ways round. Layout checks (lengths, closure, clearances, zones on the road,
## climbs that climb) and a bots-only race on every track and direction.

const DT := 1.0 / 60.0
const THEMES := {"meadow_ring": "meadow", "canyon_dash": "canyon", "harbor_lights": "harbor", "frost_pass": "frost"}


func _models(track_id: String) -> Array:
	var def := KartTracks.build(track_id)
	return [KartTrackModel.new(def), KartTrackModel.new(def, true)]


func test_the_cup_has_four_themed_tracks() -> void:
	assert_array(KartTracks.CUP).is_equal(["meadow_ring", "canyon_dash", "harbor_lights", "frost_pass"])
	for id in KartTracks.CUP:
		var def := KartTracks.build(id)
		assert_str(def.id).is_equal(id)
		assert_str(def.theme).is_equal(THEMES[id])
		assert_str(def.title).is_not_empty()
		assert_int(def.half_widths.size()).is_equal(def.points.size())
		assert_int(def.banking.size()).is_equal(def.points.size())
		# About 1.0-1.4 km: 55-75 s laps at 60% FTP (the spec).
		assert_float(KartTracks.length_of(id)).override_failure_message("%s length" % id).is_between(1000.0, 1400.0)


func test_route_cards_close_on_themselves() -> void:
	for id in ["canyon_dash", "harbor_lights", "frost_pass"]:
		var script: GDScript = load(KartTracks.SCRIPTS[id])
		var ab := KartTrackShape.solve(script.shape)
		# The two sized straights are real straights.
		assert_float(minf(ab.x, ab.y)).override_failure_message("%s straights %s" % [id, ab]).is_greater(25.0)
		var shape: KartTrackShape = script.shape(ab.x, ab.y)
		shape.def(id, id, "x")
		assert_float(shape.closure_error).is_less(0.5)
		assert_float(absf(shape.heading_error())).is_less(0.5)


func test_a_turtle_arc_turns_the_way_it_says() -> void:
	# A left-hand square with rounded corners: every corner curves left in the track model.
	var t := KartTrackShape.new()
	for i in 4:
		t.straight(80.0)
		t.arc(30.0, 90.0)
	var model := KartTrackModel.new(t.def("sq", "sq", "meadow"))
	assert_float(model.length).is_between(4.0 * 80.0 + TAU * 30.0 - 10.0, 4.0 * 80.0 + TAU * 30.0 + 10.0)
	var s := 0.0
	var most := 0.0
	while s < model.length:
		most = maxf(most, model.curvature(s))
		assert_float(model.curvature(s)).is_greater(-0.004)
		s += 5.0
	assert_float(most).is_between(1.0 / 36.0, 1.0 / 24.0)


func test_separate_stretches_of_road_keep_clear_of_each_other() -> void:
	for id in KartTracks.CUP:
		var m: KartTrackModel = _models(id)[0]
		var s := 0.0
		while s < m.length:
			var p := m.sample(s).position
			var u := 0.0
			while u < m.length:
				if absf(m.delta(s, u)) > 80.0:
					var q := m.sample(u).position
					var gap := Vector2(p.x - q.x, p.z - q.z).length() - (m.half_width(s) + m.half_width(u) + 2.0 * m.verge)
					assert_float(gap).override_failure_message("%s: s=%.0f and %.0f only %.1f m apart" % [id, s, u, gap]).is_greater(15.0)
				u += 6.0
			s += 6.0


func test_zones_lie_on_the_road_both_ways_round() -> void:
	for id in KartTracks.CUP:
		for m: KartTrackModel in _models(id):
			var types := {}
			for z in m.zones:
				types[z.type] = types.get(z.type, 0) + 1
				assert_float(float(z.s0)).is_between(0.0, m.length)
				assert_float(float(z.s1)).is_between(0.0, m.length)
				if z.type in ["boost", "items"]:
					var w := float(z.get("w", 0.0))
					for s: float in [float(z.s0), float(z.s1)]:
						assert_float(absf(float(z.get("d", 0.0))) + w).override_failure_message("%s %s off the road" % [id, z]).is_less(m.half_width(s) - 0.5)
					# Item rows and pads sit on gentle road, not mid-hairpin.
					assert_float(absf(m.curvature(z.s0))).override_failure_message("%s %s in a tight corner" % [id, z]).is_less(1.0 / 35.0)
			assert_int(types.get("start", 0)).is_equal(1)
			assert_int(types.get("items", 0)).is_equal(2)
			assert_int(types.get("boost", 0)).is_equal(2)
			assert_int(types.get("climb", 0)).override_failure_message("%s climbs (reversed %s)" % [id, m.reversed]).is_equal(1)
			# The start zone covers the line and the grid behind it.
			assert_bool(m.zones_at(0.5).any(func(z): return z.type == "start")).is_true()
			assert_bool(m.zones_at(m.wrap(-45.0)).any(func(z): return z.type == "start")).is_true()
			assert_bool(m.zones_at(45.0).any(func(z): return z.type == "start")).is_true()
			# The grid is straight and wide (Meadow Ring's, the hero slice's, curves gently).
			var g := -42.0
			while g < 2.0 and id != "meadow_ring":
				assert_float(absf(m.curvature(m.wrap(g)))).override_failure_message("%s grid bends at %.0f" % [id, g]).is_less(0.008)
				assert_float(m.half_width(m.wrap(g))).is_greater(6.8)
				g += 2.0


func test_climb_zones_climb_in_their_direction() -> void:
	for id in KartTracks.CUP:
		for m: KartTrackModel in _models(id):
			for z in m.zones:
				if z.type != "climb":
					continue
				var span := m.delta(z.s0, z.s1)
				var rise := m.sample(z.s1).position.y - m.sample(z.s0).position.y
				assert_float(span).is_greater(100.0)
				assert_float(rise / span).override_failure_message("%s reversed=%s climb %.0f-%.0f rises %.1f m" % [id, m.reversed, z.s0, z.s1, rise]).is_greater(0.025)


func test_bots_lap_every_track_both_ways() -> void:
	for id in KartTracks.CUP:
		for m: KartTrackModel in _models(id):
			var race := KartRaceLogic.new()
			var racers := []
			var bots := []
			for i in 8:
				racers.append({"racer_id": "r%d" % i, "weight": 1.0})
				bots.append(KartBotDriver.new({"power_pct": 0.45 + 0.04 * i, "line_offset": [-1.5, 1.5, -0.5, 0.5, -2.0, 2.0, 0.0, 1.0][i]}, 150.0, i + 1))
			race.setup(m, racers, 3)
			var bumps := [0]
			race.events.wall_bump.connect(func(_id: int, strength: float):
				if strength > 0.3:
					bumps[0] += 1)
			race.start_countdown(0.0)
			var inputs := []
			inputs.resize(8)
			var limit := 1.8 * m.length / KartPhysics.steady_bike_speed(150.0 * 0.45, 0.0) / KartPhysics.SPEED_SCALE + 10.0
			var t := 0.0
			while t < limit:
				for i in 8:
					inputs[i] = bots[i].think(race.karts[i], race, DT)
				race.step(DT, inputs)
				t += DT
			for k: KartState in race.karts:
				assert_int(k.lap).override_failure_message("%s reversed=%s: kart %d stuck at s=%.0f lap %d" % [id, m.reversed, k.id, k.s, k.lap]).is_greater_equal(2)
			assert_int(bumps[0]).override_failure_message("%s reversed=%s: %d hard wall bumps" % [id, m.reversed, bumps[0]]).is_less(4)
