extends GdUnitTestSuite
## Kart Race's track space (#43): a closed centre line baked to a lookup table, queried by
## (s, d). s runs along the road from the start line, d across it (+ = the driver's right).

const MEADOW := "res://games/kart_race/tracks/meadow_ring.gd"


## A closed circle of radius `r`, driven anticlockwise seen from above (every turn a left).
func _circle(r := 60.0, n := 24, half_width := 6.0) -> KartTrackDef:
	var def := KartTrackDef.new()
	def.id = "circle"
	var pts := PackedVector3Array()
	var widths := PackedFloat32Array()
	var bank := PackedFloat32Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector3(r * cos(a), 0.0, -r * sin(a)))
		widths.append(half_width)
		bank.append(0.0)
	def.points = pts
	def.half_widths = widths
	def.banking = bank
	return def


## A paperclip: two 200 m straights whose centre lines are only 10 m apart, joined by hairpins.
func _paperclip() -> KartTrackDef:
	var def := KartTrackDef.new()
	def.id = "paperclip"
	var pts := PackedVector3Array()
	for x in [0.0, 50.0, 100.0, 150.0, 200.0]:
		pts.append(Vector3(x, 0.0, 0.0))
	pts.append(Vector3(212.0, 0.0, -5.0))
	for x in [200.0, 150.0, 100.0, 50.0, 0.0]:
		pts.append(Vector3(x, 0.0, -10.0))
	pts.append(Vector3(-12.0, 0.0, -5.0))
	def.points = pts
	var widths := PackedFloat32Array()
	var bank := PackedFloat32Array()
	for i in pts.size():
		widths.append(3.0)
		bank.append(0.0)
	def.half_widths = widths
	def.banking = bank
	def.verge = 3.0
	return def


func _meadow() -> KartTrackDef:
	return load(MEADOW).build()


func _polyline_length(def: KartTrackDef) -> float:
	var total := 0.0
	for i in def.points.size():
		total += def.points[i].distance_to(def.points[(i + 1) % def.points.size()])
	return total


func test_length_is_within_one_percent_of_the_polyline() -> void:
	for def in [_circle(), _meadow()]:
		var track := KartTrackModel.new(def)
		var poly := _polyline_length(def)
		assert_float(track.length).override_failure_message("%s: %.1f vs %.1f" % [def.id, track.length, poly]) \
			.is_between(poly, poly * 1.01)
	# A circle's spline stays close to the true circle.
	assert_float(KartTrackModel.new(_circle(60.0, 24)).length).is_equal_approx(TAU * 60.0, TAU * 60.0 * 0.01)


func test_project_round_trips_s_and_d() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	for def in [_meadow(), _circle()]:
		var track := KartTrackModel.new(def)
		for i in 200:
			var s := rng.randf_range(0.0, track.length)
			var reach := track.half_width(s) + track.verge
			var d := rng.randf_range(-reach, reach)
			var p := track.project(track.position_at(s, d))
			assert_float(absf(track.delta(s, p.s))).override_failure_message("s %.3f -> %.3f (d %.2f)" % [s, p.s, d]).is_less(0.05)
			assert_float(p.d).override_failure_message("d %.3f -> %.3f at s %.2f" % [d, p.d, s]).is_equal_approx(d, 0.05)
			# With a hint near the answer, the same.
			var hinted := track.project(track.position_at(s, d), track.wrap(s + 3.0))
			assert_float(absf(track.delta(s, hinted.s))).is_less(0.05)


func test_project_with_a_hint_stays_on_its_branch() -> void:
	var track := KartTrackModel.new(_paperclip())
	# A point in the first straight's right verge, nearer the other straight's centre line.
	var s := 100.0
	var probe := track.position_at(s, -5.5)
	var on_branch := track.project(probe, s)
	assert_float(absf(track.delta(s, on_branch.s))).is_less(0.05)
	assert_float(on_branch.d).is_equal_approx(-5.5, 0.05)
	# Without a hint the nearest centre line wins: the other branch.
	var nearest := track.project(probe)
	assert_float(absf(track.delta(s, nearest.s))).is_greater(50.0)


func test_surface_changes_at_half_width_kerb_and_verge() -> void:
	var track := KartTrackModel.new(_circle(60.0, 24, 6.0))
	var edge := track.half_width(10.0)
	assert_float(edge).is_equal_approx(6.0, 0.001)
	assert_int(track.surface(10.0, 0.0)).is_equal(KartTrackModel.Surface.ROAD)
	assert_int(track.surface(10.0, edge - 0.01)).is_equal(KartTrackModel.Surface.ROAD)
	assert_int(track.surface(10.0, -(edge + 0.1))).is_equal(KartTrackModel.Surface.KERB)
	assert_int(track.surface(10.0, edge + KartTrackModel.KERB_WIDTH + 0.1)).is_equal(KartTrackModel.Surface.OFFROAD)
	assert_int(track.surface(10.0, edge + track.verge - 0.05)).is_equal(KartTrackModel.Surface.OFFROAD)
	assert_int(track.surface(10.0, -(edge + track.verge + 0.05))).is_equal(KartTrackModel.Surface.WALL)


func test_curvature_is_positive_on_a_left_turn() -> void:
	var track := KartTrackModel.new(_circle(60.0, 24))
	for s in [0.0, 50.0, 200.0, 333.0]:
		assert_float(track.curvature(s)).is_equal_approx(1.0 / 60.0, 0.002)
	# Driving anticlockwise, the right is away from the centre.
	var p := track.sample(0.0)
	assert_float(p.position.length()).is_equal_approx(60.0, 0.5)
	assert_float(p.right.dot(p.position.normalized())).is_greater(0.99)
	assert_float(track.position_at(0.0, 5.0).length()).is_equal_approx(65.0, 0.5)


func test_delta_wraps_around_the_loop() -> void:
	var track := KartTrackModel.new(_meadow())
	var l := track.length
	assert_float(track.delta(0.98 * l, 0.02 * l)).is_equal_approx(0.04 * l, 0.001)
	assert_float(track.delta(0.02 * l, 0.98 * l)).is_equal_approx(-0.04 * l, 0.001)
	assert_float(track.delta(10.0, 30.0)).is_equal_approx(20.0, 0.001)
	assert_float(track.wrap(-1.0)).is_equal_approx(l - 1.0, 0.001)
	assert_float(track.wrap(l + 2.0)).is_equal_approx(2.0, 0.001)


func test_reversed_flips_direction_and_curvature() -> void:
	var def := _meadow()
	var fwd := KartTrackModel.new(def)
	var rev := KartTrackModel.new(def, true)
	assert_float(rev.length).is_equal_approx(fwd.length, 0.5)
	# The start line stays put.
	assert_float(rev.sample(0.0).position.distance_to(fwd.sample(0.0).position)).is_less(0.05)
	for s in [37.0, 300.0, 512.0, 800.0, 1020.0]:
		var p := fwd.sample(s)
		var q := rev.project(p.position)
		assert_float(q.position.distance_to(p.position)).is_less(0.05)
		assert_float(q.tangent.dot(p.tangent)).is_less(-0.99)
		assert_float(rev.curvature(q.s)).is_equal_approx(-fwd.curvature(s), 0.002)
		assert_float(rev.grade(q.s)).is_equal_approx(-fwd.grade(s), 0.005)
		# d flips with the direction too.
		var side := rev.project(fwd.position_at(s, 2.0))
		assert_float(side.d).is_equal_approx(-2.0, 0.05)


func test_racing_line_stays_on_the_road() -> void:
	for def in [_meadow(), _circle()]:
		var track := KartTrackModel.new(def)
		var s := 0.0
		var used := 0.0
		while s < track.length:
			var limit := track.half_width(s) - 1.2
			assert_float(absf(track.racing_line(s))).override_failure_message("%s at %.0f" % [def.id, s]).is_less_equal(limit)
			used = maxf(used, absf(track.racing_line(s)))
			s += 2.0
		# It does use the road: the inside of corners.
		assert_float(used).is_greater(1.0)
	# On a left-hand circle the line hugs the left (inside).
	assert_float(KartTrackModel.new(_circle()).racing_line(100.0)).is_less(-1.0)


func test_meadow_ring_has_its_zones_and_climb() -> void:
	var def := _meadow()
	var track := KartTrackModel.new(def)
	assert_float(track.length).is_between(1000.0, 1250.0)
	var types := {}
	for z in track.zones:
		types[z.type] = types.get(z.type, 0) + 1
	assert_int(types.get("climb", 0)).is_equal(1)
	assert_int(types.get("items", 0)).is_equal(2)
	assert_int(types.get("boost", 0)).is_equal(2)
	assert_int(types.get("start", 0)).is_equal(1)
	var climb: Dictionary = track.zones.filter(func(z): return z.type == "climb")[0]
	var mid := track.wrap(climb.s0 + track.delta(climb.s0, climb.s1) * 0.5)
	assert_float(track.grade(mid)).is_greater(0.02)
	assert_bool(track.zones_at(mid).any(func(z): return z.type == "climb")).is_true()
	# Every pad, item row and the start lie on the road.
	for z in track.zones:
		if z.type in ["boost", "items", "start"]:
			assert_float(absf(float(z.get("d", 0.0)))).is_less(track.half_width(z.s0))


func test_zones_wrap_and_reverse() -> void:
	var def := _circle()
	def.zones = [{"type": "climb", "s0": 100.0, "s1": 150.0}, {"type": "start", "s0": 360.0, "s1": 10.0}]
	var track := KartTrackModel.new(def)
	assert_bool(track.zones_at(120.0).size() == 1 and track.zones_at(120.0)[0].type == "climb").is_true()
	assert_bool(track.zones_at(5.0).any(func(z): return z.type == "start")).is_true()
	assert_bool(track.zones_at(track.length - 1.0).any(func(z): return z.type == "start")).is_true()
	assert_array(track.zones_at(200.0)).is_empty()
	# Reversed: the same stretch of road, driven the other way.
	var rev := KartTrackModel.new(def, true)
	var p := rev.project(track.sample(120.0).position)
	assert_bool(rev.zones_at(p.s).any(func(z): return z.type == "climb")).is_true()
	assert_array(rev.zones_at(rev.project(track.sample(200.0).position).s)).is_empty()
