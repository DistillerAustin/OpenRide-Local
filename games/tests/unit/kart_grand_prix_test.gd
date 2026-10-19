extends GdUnitTestSuite
## Kart Race's Grand Prix (#43): how many races fit the ride, the final race's laps, the track
## order (reversed the second time round), points and the tie-break.

const CUP := ["meadow_ring", "canyon_dash", "harbor_lights", "frost_pass"]


## Plays a GP of `duration` seconds where each race takes exactly its estimate. Returns the races.
func _plan(duration: float, est_lap: float) -> Array:
	var gp := KartGrandPrix.new(duration, CUP)
	var left := duration
	var races := []
	for i in 40:
		var race := gp.next_race(left, est_lap)
		race["time_left"] = left
		races.append(race)
		gp.record(range(8))
		left -= race.laps * est_lap + KartGrandPrix.RACE_OVERHEAD_SEC
		if race.is_final:
			break
	return races


func test_twenty_minutes_of_one_minute_laps_is_five_or_six_races() -> void:
	var races := _plan(1200.0, 60.0)
	assert_int(races.size()).is_between(5, 6)
	for race in races.slice(0, races.size() - 1):
		assert_bool(race.is_final).is_false()
		assert_int(race.laps).is_equal(3)
	var last: Dictionary = races.back()
	assert_bool(last.is_final).is_true()
	assert_int(last.laps).is_between(1, 5)
	# The final race's laps fill the time that was left, to within a lap.
	assert_float(absf(last.laps * 60.0 - float(last.time_left))).is_less_equal(60.0)
	for i in races.size():
		assert_int(races[i].index).is_equal(i)


func test_five_minutes_is_a_single_race() -> void:
	var races := _plan(300.0, 60.0)
	assert_int(races.size()).is_equal(1)
	assert_bool(races[0].is_final).is_true()
	assert_int(races[0].laps).is_equal(5)


func test_an_open_ended_grand_prix_never_flags_a_final() -> void:
	var gp := KartGrandPrix.new(-1.0, CUP)
	for i in 30:
		var race := gp.next_race(-1.0, 60.0)
		assert_bool(race.is_final).is_false()
		assert_int(race.laps).is_equal(3)
		gp.record(range(8))


func test_tracks_go_in_cup_order_and_reverse_the_second_time_round() -> void:
	var gp := KartGrandPrix.new(-1.0, CUP)
	var seen := []
	for i in 12:
		var race := gp.next_race(-1.0, 60.0)
		seen.append([race.track_id, race.reversed])
	for i in 4:
		assert_array(seen[i]).is_equal([CUP[i], false])
		assert_array(seen[i + 4]).is_equal([CUP[i], true])
		assert_array(seen[i + 8]).is_equal([CUP[i], false])
	# A one-track cup alternates.
	var solo := KartGrandPrix.new(-1.0, ["meadow_ring"])
	assert_bool(solo.next_race(-1.0, 60.0).reversed).is_false()
	assert_bool(solo.next_race(-1.0, 60.0).reversed).is_true()


func test_points_follow_the_finishing_order() -> void:
	var gp := KartGrandPrix.new(-1.0, CUP)
	gp.record([3, 1, 2, 0, 4, 5, 6, 7])
	var table := gp.standings()
	assert_int(table.size()).is_equal(8)
	assert_int(table[0].kart_id).is_equal(3)
	assert_int(table[0].points).is_equal(15)
	assert_int(table[0].wins).is_equal(1)
	var points := {}
	for row in table:
		points[row.kart_id] = row.points
	assert_array([points[3], points[1], points[2], points[0], points[4], points[5], points[6], points[7]]) \
		.is_equal(KartGrandPrix.POINTS)
	assert_int(gp.champion()).is_equal(3)
	assert_int(gp.races_run()).is_equal(1)


func test_ties_go_to_the_better_last_race() -> void:
	var gp := KartGrandPrix.new(-1.0, CUP)
	gp.record([1, 2, 0, 3, 4, 5, 6, 7])
	gp.record([2, 1, 0, 3, 4, 5, 6, 7])
	var table := gp.standings()
	# 1 and 2 both have 27: 2 won the last race.
	assert_int(table[0].points).is_equal(27)
	assert_int(table[1].points).is_equal(27)
	assert_int(table[0].kart_id).is_equal(2)
	assert_int(table[0].best_place_last).is_equal(1)
	assert_int(table[1].kart_id).is_equal(1)
	assert_int(gp.champion()).is_equal(2)
	assert_int(gp.place_of(0)).is_equal(3)


func test_lap_estimates_stay_sensible_from_60_to_400_w() -> void:
	var length := 1150.0
	var low := KartGrandPrix.estimate_lap_sec(length, 60.0)
	var mid := KartGrandPrix.estimate_lap_sec(length, 150.0)
	var high := KartGrandPrix.estimate_lap_sec(length, 400.0)
	# The reference cruise includes the cadence term (KartPhysics.drive_power at 85 rpm).
	assert_float(low).is_between(55.0, 90.0)
	assert_float(mid).is_between(45.0, 70.0)
	assert_float(high).is_between(35.0, 55.0)
	assert_float(low).is_greater(mid)
	assert_float(mid).is_greater(high)
	# The Grand Prix still lands near the ride's length for either rider.
	for est in [low, high]:
		for duration in [600.0, 1200.0, 3600.0]:
			var races := _plan(duration, est)
			var used := 0.0
			for race in races:
				used += race.laps * est + KartGrandPrix.RACE_OVERHEAD_SEC
			assert_float(absf(used - duration)).override_failure_message("%.0f s at %.0f s laps used %.0f" % [duration, est, used]) \
				.is_less_equal(est + KartGrandPrix.RACE_OVERHEAD_SEC)
