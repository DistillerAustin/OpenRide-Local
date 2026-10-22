extends GdUnitTestSuite
## Kart Race's scoring (#43, spec "Scoring and result"): the live awards, the result stats with
## the ghost trace, and star thresholds that give about one star for a mid-pack ride.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0
const FTP := 150.0
## The framework's time around each race that counts as played: the fly-over, the countdown and
## the results board (KartRace: FLYOVER_SEC + COUNTDOWN_SEC + RESULTS_SEC).
const RACE_AROUND_SEC := 14.5
## The simulated rider's share of FTP for a mid-pack ride and a strong one, against the
## standard field (KartRace.BOT_PCTS: 0.50-1.00 since the drive power, 2026-10-19).
const MID_PCT := 0.75
const STRONG_PCT := 1.15


func _race(n := 3) -> KartRaceLogic:
	var race := KartRaceLogic.new()
	var racers := []
	for i in n:
		racers.append({"racer_id": "r%d" % i})
	race.setup(KartTrackModel.new(Fixtures.oval()), racers, 3)
	race.start_countdown(0.0)
	race.step(DT, [])
	return race


func _scoring(race: KartRaceLogic) -> Array:
	var scoring := KartScoring.new()
	var log := []
	scoring.awarded.connect(func(points: float, why: String): log.append([points, why]))
	scoring.begin_race(race)
	return [scoring, log]


func test_a_lap_scores_and_sets_the_best_lap() -> void:
	var race := _race()
	var s := _scoring(race)
	race.events.lap_completed.emit(0, 1, 62.5)
	race.events.lap_completed.emit(1, 1, 50.0)  # a bot's: nothing
	race.events.lap_completed.emit(0, 2, 60.25)
	assert_array(s[1]).is_equal([[KartScoring.LAP, "lap"], [KartScoring.LAP, "lap"]])
	assert_float(s[0].best_lap).is_equal(60.25)


func test_overtakes_score_only_for_a_place_better_than_any_so_far() -> void:
	var race := _race()
	var s := _scoring(race)
	var scoring: KartScoring = s[0]
	var start := race.place_of(0)
	assert_int(start).is_equal(3)
	race.events.position_changed.emit(0, 3, 2)
	race.events.position_changed.emit(0, 2, 3)  # passed back
	race.events.position_changed.emit(0, 3, 2)  # retaken: no farming
	race.events.position_changed.emit(0, 2, 1)
	race.events.position_changed.emit(2, 1, 2)  # someone else's
	assert_array(s[1]).is_equal([[KartScoring.OVERTAKE, "overtake"], [KartScoring.OVERTAKE, "overtake"]])
	assert_int(scoring.overtakes).is_equal(2)


func test_mini_turbos_score_by_tier_and_every_boost_counts() -> void:
	var race := _race()
	var s := _scoring(race)
	var scoring: KartScoring = s[0]
	race.events.boost_started.emit(0, "drift", 1)
	scoring.step(KartScoring.MINI_TURBO_GAP_SEC, 150.0)
	race.events.boost_started.emit(0, "drift", 3)
	scoring.step(KartScoring.MINI_TURBO_GAP_SEC, 150.0)
	race.events.boost_started.emit(0, "drift", 2)
	race.events.boost_started.emit(0, "pad", 0)
	race.events.boost_started.emit(0, "item", 0)
	race.events.boost_started.emit(1, "drift", 3)  # a bot's
	assert_array(s[1]).is_equal([[10.0, "mini_turbo"], [35.0, "mini_turbo"], [20.0, "mini_turbo"]])
	assert_int(scoring.boosts).is_equal(5)


func test_mini_turbos_back_to_back_score_once() -> void:
	# Wiggling hard on a straight to farm drifts doesn't pay.
	var race := _race()
	var s := _scoring(race)
	var scoring: KartScoring = s[0]
	for i in 6:
		race.events.boost_started.emit(0, "drift", 1)
		scoring.step(0.8, 150.0)
	assert_int(s[1].size()).is_less_equal(2)
	assert_int(scoring.boosts).is_equal(6)


func test_an_item_hit_scores_for_the_rider_only() -> void:
	var race := _race()
	var s := _scoring(race)
	race.events.kart_hit.emit(1, 0, "puck")
	race.events.kart_hit.emit(0, 1, "puck")
	race.events.kart_hit.emit(2, 1, "drone")
	assert_array(s[1]).is_equal([[KartScoring.ITEM_HIT, "item_hit"]])
	assert_int(s[0].items_hit).is_equal(1)


func test_the_finish_scores_the_race_points() -> void:
	var race := _race()
	var s := _scoring(race)
	race.events.race_finished.emit([2, 0, 1])
	assert_array(s[1]).is_equal([[KartGrandPrix.POINTS[1] * KartScoring.RACE_POINT, "race"]])


func test_the_ghost_trace_samples_the_riders_distance_each_second_and_stays_bounded() -> void:
	var race := _race()
	var s := _scoring(race)
	var scoring: KartScoring = s[0]
	var k: KartState = race.karts[0]
	for i in 600:
		k.s = race.track.wrap(k.s + 0.2)
		if k.s < 0.2:
			k.lap += 1
		scoring.step(DT, 120.0)
	assert_int(scoring.ghost_trace.size()).is_equal(10)
	assert_int(scoring.ghost_trace[9]).is_between(119, 121)
	# Strictly growing for a kart driving forward.
	for i in range(1, scoring.ghost_trace.size()):
		assert_int(scoring.ghost_trace[i]).is_greater(scoring.ghost_trace[i - 1])
	# Two hours fit in KartScoring.GHOST_MAX_POINTS by halving the resolution.
	for i in 7200 * 4:
		scoring.step(0.25, 120.0)
	assert_int(scoring.ghost_trace.size()).is_less_equal(KartScoring.GHOST_MAX_POINTS)
	assert_int(scoring.ghost_trace.size()).is_greater(KartScoring.GHOST_MAX_POINTS / 2)
	assert_float(scoring.avg_power()).is_equal_approx(120.0, 0.01)


func test_the_stats_have_every_result_key() -> void:
	var race := _race()
	var s := _scoring(race)
	var scoring: KartScoring = s[0]
	var gp := KartGrandPrix.new(1200.0, ["meadow_ring"], 3)
	race.events.race_finished.emit([0, 1, 2])
	gp.record([0, 1, 2])
	var stats := scoring.stats(gp)
	for key in ["position", "races", "wins", "podiums", "best_lap", "race_time", "boosts", "items_hit",
			"avg_power", "ghost_trace"]:
		assert_bool(stats.has(key)).override_failure_message("missing %s" % key).is_true()
	assert_int(int(stats.wins)).is_equal(1)
	assert_int(int(stats.podiums)).is_equal(1)
	assert_int(int(stats.position)).is_equal(1)


func test_every_difficulty_has_three_rising_star_thresholds() -> void:
	for difficulty in ["easy", "standard", "hard"]:
		var t: Array = KartScoring.STAR_THRESHOLDS[difficulty]
		assert_int(t.size()).is_equal(3)
		assert_bool(t[0] < t[1] and t[1] < t[2]).is_true()


## A whole race on Meadow Ring with items and bots: kart 0 is driven by the bot policy at
## `rider_pct` of FTP against the standard field, scored at 1.0×. Returns [points per minute
## of play, the rider's place].
func _simulated_ride(rider_pct: float, seed_base: int) -> Array:
	var race := KartRaceLogic.new()
	var racers := []
	for i in 8:
		racers.append({"racer_id": "r%d" % i})
	race.setup(KartTrackModel.new(Fixtures.meadow()), racers, 3)
	var bots := []
	bots.append(KartBotDriver.new(KartBotDriver.profile_for(3, rider_pct), FTP, seed_base))
	for i in range(1, 8):
		var span: Array = preload("res://games/kart_race/KartRace.gd").BOT_PCTS.standard
		var pct := lerpf(span[0], span[1], float(7 - i) / 6.0)  # kart 1 on pole is the strongest
		bots.append(KartBotDriver.new(KartBotDriver.profile_for(i - 1, pct), FTP, seed_base * 10 + i))
	var items := KartItemLogic.new(race, seed_base)
	for b in bots:
		b.items = items
	var scoring := KartScoring.new()
	var total := [0.0]
	scoring.awarded.connect(func(points: float, _why: String): total[0] += points)
	scoring.begin_race(race)
	race.start_countdown(3.0)
	var inputs := []
	inputs.resize(8)
	var t := 0.0
	while race.phase != KartRaceLogic.Phase.FINISHED and t < 900.0:
		for i in 8:
			inputs[i] = bots[i].think(race.karts[i], race, DT)
		race.step(DT, inputs)
		items.step(DT, inputs)
		scoring.step(DT, inputs[0].power_w)
		t += DT
	var minutes := (scoring.race_time + RACE_AROUND_SEC) / 60.0
	return [total[0] / minutes, race.place_of(0)]


func test_a_mid_pack_ride_earns_about_one_star() -> void:
	var t: Array = KartScoring.STAR_THRESHOLDS.standard
	var ppm := 0.0
	var places := []
	for run in 3:
		var r := _simulated_ride(MID_PCT, run + 1)
		ppm += float(r[0]) / 3.0
		places.append(r[1])
	print("mid-pack ride: %.0f points/min, places %s" % [ppm, places])
	assert_float(ppm).override_failure_message("%.0f/min against %s" % [ppm, t]).is_between(float(t[0]), float(t[1]) - 1.0)


func test_a_strong_ride_beats_a_mid_pack_one_but_three_stars_take_more() -> void:
	var t: Array = KartScoring.STAR_THRESHOLDS.standard
	var r := _simulated_ride(STRONG_PCT, 4)
	print("strong ride: %.0f points/min, place %d" % [r[0], r[1]])
	assert_int(int(r[1])).is_less_equal(3)
	assert_float(float(r[0])).is_greater_equal(float(t[1]))
	# Three stars take podiums plus effort: not at 1.0×, but at the full 1.5×.
	assert_float(float(r[0])).is_less(float(t[2]))
	assert_float(float(r[0]) * 1.5).is_greater_equal(float(t[2]))
