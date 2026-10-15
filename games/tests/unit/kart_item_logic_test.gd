extends GdUnitTestSuite
## Kart Race's items (#43, spec "Items"): the pods and their roulette, the odds by position, the
## six items and their projectiles, the shield, and the events they emit.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0


## A race on a long oval with `n` karts parked at the given (s, d) and RACING.
func _race(spots: Array, track_def: KartTrackDef = null) -> KartRaceLogic:
	var race := KartRaceLogic.new()
	var track := KartTrackModel.new(track_def if track_def else Fixtures.oval(400.0, 40.0, 6.0))
	var racers := []
	for i in spots.size():
		racers.append({"racer_id": "r%d" % i, "weight": 1.0})
	race.setup(track, racers, 3)
	for i in spots.size():
		_place(race, race.karts[i], spots[i].x, spots[i].y)
	race.phase = KartRaceLogic.Phase.RACING
	race._update_places()
	return race


func _place(race: KartRaceLogic, k: KartState, s: float, d: float) -> void:
	var p := race.track.project(race.track.position_at(race.track.wrap(s), d), race.track.wrap(s))
	k.s = p.s
	k.d = p.d
	k.pos = p.position
	k.heading = race.track.yaw_at(p.s)
	k.lap = 1


func _inputs(n: int) -> Array:
	var out := []
	for i in n:
		out.append(KartInput.new())
	return out


func _run(items: KartItemLogic, inputs: Array, seconds: float) -> void:
	for i in roundi(seconds / DT):
		items.step(DT, inputs)
		for inp: KartInput in inputs:
			inp.use_item = false


func _fire(items: KartItemLogic, inputs: Array, kart_id: int, item: String) -> void:
	items.give(kart_id, item)
	inputs[kart_id].use_item = true
	items.step(DT, inputs)
	inputs[kart_id].use_item = false


func _share(odds: Dictionary, names: Array) -> float:
	var total := 0.0
	var part := 0.0
	for key in odds:
		total += float(odds[key])
		if key in names:
			part += float(odds[key])
	return part / total


# --- Odds ---

func test_the_odds_are_weighted_by_position() -> void:
	var lead := KartItemLogic.odds(1, 8)
	var back := KartItemLogic.odds(8, 8)
	var mid := KartItemLogic.odds(5, 8)
	# Leaders get defensive items, the back of the pack catch-up items.
	assert_float(_share(lead, ["shield", "goo"])).is_greater(_share(back, ["shield", "goo"]) + 0.3)
	assert_float(_share(back, ["drone", "magnet", "turbo"])).is_greater(_share(lead, ["drone", "magnet", "turbo"]) + 0.3)
	assert_float(_share(mid, ["drone", "magnet", "turbo"])).is_between(
		_share(lead, ["drone", "magnet", "turbo"]), _share(back, ["drone", "magnet", "turbo"]))
	# There is nobody ahead of the leader to chase.
	assert_float(float(lead.get("drone", 0))).is_equal(0.0)
	assert_float(float(lead.get("magnet", 0))).is_equal(0.0)
	# Every item can turn up somewhere.
	for item in KartItemLogic.ITEMS:
		assert_bool(float(back.get(item, 0)) + float(lead.get(item, 0)) + float(mid.get(item, 0)) > 0.0).is_true()


func test_rolls_follow_the_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts := {}
	for i in 4000:
		var item := KartItemLogic.roll(8, 8, rng)
		counts[item] = int(counts.get(item, 0)) + 1
	var odds := KartItemLogic.odds(8, 8)
	var total := 0.0
	for key in odds:
		total += float(odds[key])
	for key in odds:
		assert_float(float(counts.get(key, 0)) / 4000.0).override_failure_message("share of %s" % key) \
			.is_equal_approx(float(odds[key]) / total, 0.03)


# --- Pods ---

func test_pods_stand_in_rows_across_the_road_at_each_item_zone() -> void:
	var def := Fixtures.meadow()
	var race := _race([Vector2(0, 0)], def)
	var items := KartItemLogic.new(race, 1)
	var rows := 0
	for z in race.track.zones:
		if z.type == "items":
			rows += 1
	assert_int(rows).is_greater_equal(2)
	assert_int(items.pods.size()).is_between(rows * 4, rows * 5)
	for pod: KartItemLogic.Pod in items.pods:
		assert_float(absf(pod.d)).is_less(race.track.half_width(pod.s) - 0.5)
		assert_int(race.track.surface(pod.s, pod.d)).is_equal(KartTrackModel.Surface.ROAD)


func test_driving_through_a_pod_gives_a_bot_an_item_at_once_and_the_rider_a_roulette() -> void:
	var race := _race([Vector2(100, 0), Vector2(100, 3)])
	var items := KartItemLogic.new(race, 3)
	items.pods.clear()
	items.add_pod(race.track.wrap(100.0), 0.0)
	items.add_pod(race.track.wrap(100.0), 3.0)
	var picked := []
	race.events.item_picked.connect(func(id: int, item: String): picked.append([id, item]))
	var inputs := _inputs(2)
	items.step(DT, inputs)
	var rider: KartState = race.karts[0]
	var bot: KartState = race.karts[1]
	# The bot's roulette is skipped.
	assert_str(bot.item).is_not_empty()
	assert_float(bot.roulette_time).is_equal(0.0)
	# The rider's spins for 0.9 s, then lands.
	assert_str(rider.item).is_empty()
	assert_float(rider.roulette_time).is_equal_approx(KartItemLogic.ROULETTE_SEC, 0.02)
	_run(items, inputs, 0.8)
	assert_str(rider.item).is_empty()
	_run(items, inputs, 0.15)
	assert_str(rider.item).is_not_empty()
	assert_array(picked).has_size(2)
	assert_int(int(picked[0][0])).is_equal(1)
	assert_int(int(picked[1][0])).is_equal(0)
	# Both pods are broken, and come back 3 s after the pickup.
	assert_bool(items.pods[0].ready()).is_false()
	_run(items, inputs, KartItemLogic.POD_RESPAWN_SEC - 1.0)
	assert_bool(items.pods[0].ready()).is_false()
	_place(race, rider, 300.0, 0.0)
	_place(race, bot, 300.0, 3.0)
	_run(items, inputs, 0.2)
	assert_bool(items.pods[0].ready()).is_true()


func test_holding_an_item_a_pod_still_breaks_but_gives_nothing_new() -> void:
	var race := _race([Vector2(100, 3), Vector2(100, 0)])
	var items := KartItemLogic.new(race, 3)
	items.pods.clear()
	items.add_pod(race.track.wrap(100.0), 0.0)
	items.give(1, "shield")
	items.step(DT, _inputs(2))
	assert_str(race.karts[1].item).is_equal("shield")
	assert_bool(items.pods[0].ready()).is_false()


# --- The items ---

func test_an_item_is_used_on_the_tap_and_only_once() -> void:
	var race := _race([Vector2(100, 0)])
	var items := KartItemLogic.new(race, 1)
	var used := []
	race.events.item_used.connect(func(id: int, item: String): used.append([id, item]))
	var inputs := _inputs(1)
	# Nothing held: nothing happens.
	inputs[0].use_item = true
	items.step(DT, inputs)
	assert_array(used).is_empty()
	_fire(items, inputs, 0, "turbo")
	assert_array(used).is_equal([[0, "turbo"]])
	assert_str(race.karts[0].item).is_empty()
	inputs[0].use_item = true
	items.step(DT, inputs)
	assert_array(used).has_size(1)


func test_the_rider_cannot_use_an_item_during_the_roulette() -> void:
	var race := _race([Vector2(100, 0)])
	var items := KartItemLogic.new(race, 1)
	items.pods.clear()
	items.add_pod(race.track.wrap(100.0), 0.0)
	var inputs := _inputs(1)
	items.step(DT, inputs)
	inputs[0].use_item = true
	items.step(DT, inputs)
	inputs[0].use_item = false
	assert_float(race.karts[0].roulette_time).is_greater(0.0)
	_run(items, inputs, 1.0)
	assert_str(race.karts[0].item).is_not_empty()


func test_the_turbo_can_boosts() -> void:
	var race := _race([Vector2(100, 0)])
	var items := KartItemLogic.new(race, 1)
	var boosts := []
	race.events.boost_started.connect(func(id: int, kind: String, tier: int): boosts.append([id, kind, tier]))
	var k: KartState = race.karts[0]
	k.speed = 15.0
	_fire(items, _inputs(1), 0, "turbo")
	assert_float(k.boost_time).is_equal_approx(KartItemLogic.TURBO_SEC, 0.05)
	assert_float(k.speed).is_greater(15.0)
	assert_array(boosts).is_equal([[0, "item", 0]])


func test_the_shield_blocks_one_hit() -> void:
	var race := _race([Vector2(100, 0), Vector2(60, 0)])
	var items := KartItemLogic.new(race, 1)
	var hits := []
	var blocked := []
	race.events.kart_hit.connect(func(id: int, by: int, item: String): hits.append([id, by, item]))
	race.events.shield_blocked.connect(func(id: int): blocked.append(id))
	var inputs := _inputs(2)
	_fire(items, inputs, 0, "shield")
	var k: KartState = race.karts[0]
	assert_float(k.shield_time).is_equal_approx(KartItemLogic.SHIELD_SEC, 0.05)
	k.speed = 20.0
	# The first hit is absorbed.
	items.hit(k, 1, "puck")
	assert_array(blocked).is_equal([0])
	assert_array(hits).is_empty()
	assert_float(k.spin_time).is_equal(0.0)
	assert_float(k.speed).is_equal(20.0)
	assert_float(k.shield_time).is_equal(0.0)
	# The second spins the kart out.
	items.hit(k, 1, "puck")
	assert_array(hits).is_equal([[0, 1, "puck"]])
	assert_float(k.spin_time).is_greater(0.0)
	assert_float(k.speed).is_less(20.0)


func test_the_puck_flies_forward_and_spins_out_the_first_kart_it_hits() -> void:
	# The rider fires at a kart 30 m ahead in its lane; a kart further on is spared.
	var race := _race([Vector2(100, 0), Vector2(130, 0), Vector2(150, 0)])
	var items := KartItemLogic.new(race, 1)
	var hits := []
	race.events.kart_hit.connect(func(id: int, by: int, item: String): hits.append([id, by, item]))
	var inputs := _inputs(3)
	race.karts[1].speed = 10.0
	_fire(items, inputs, 0, "puck")
	assert_int(items.shots.size()).is_equal(1)
	_run(items, inputs, 2.0)
	assert_array(hits).is_equal([[1, 0, "puck"]])
	assert_float(race.karts[1].spin_time).is_greater(0.0)
	assert_float(race.karts[2].spin_time).is_equal(0.0)
	assert_int(items.live_shots()).is_equal(0)


func test_the_puck_bounces_off_the_walls_at_most_three_times() -> void:
	# A wide circle with nobody to hit: aimed across the road, the puck ricochets and dies.
	var race := _race([Vector2(10, 0)], Fixtures.circle(60.0, 24, 6.0, 4.0))
	var items := KartItemLogic.new(race, 1)
	var k: KartState = race.karts[0]
	k.heading += 0.5  # angled toward the inside wall
	_fire(items, _inputs(1), 0, "puck")
	var shot: KartItemLogic.Shot = items.shots[0]
	var most := 0
	for i in roundi(KartItemLogic.PUCK_LIFE_SEC / DT) + 10:
		items.step(DT, _inputs(1))
		most = maxi(most, shot.bounces)
		if not shot.alive:
			break
		var reach := race.track.half_width(shot.s) + race.track.verge
		assert_float(absf(shot.d)).is_less_equal(reach)
	assert_int(most).is_between(1, KartItemLogic.PUCK_BOUNCES)
	assert_bool(shot.alive).is_false()


func test_a_puck_can_come_back_and_hit_its_owner_but_not_at_once() -> void:
	var race := _race([Vector2(100, 0)])
	var items := KartItemLogic.new(race, 1)
	var hits := []
	race.events.kart_hit.connect(func(id: int, by: int, item: String): hits.append([id, by, item]))
	_fire(items, _inputs(1), 0, "puck")
	_run(items, _inputs(1), 0.1)
	assert_array(hits).is_empty()


func test_the_drone_reaches_the_next_kart_ahead() -> void:
	# The rider is last; the kart one place ahead is 120 m on, off the racing line. The kart
	# beyond it and the leader (a lap up, sitting in the drone's path) are left alone.
	var race := _race([Vector2(100, 0), Vector2(220, 3.5), Vector2(250, -1.0), Vector2(170, 0.0)])
	race.karts[3].lap = 2  # a lap up: the leader, though it sits behind on the road
	race._update_places()
	var ahead := -1
	for kk: KartState in race.karts:
		if kk.place == race.karts[0].place - 1:
			ahead = kk.id
	assert_int(ahead).is_equal(1)
	var items := KartItemLogic.new(race, 1)
	var hits := []
	race.events.kart_hit.connect(func(id: int, by: int, item: String): hits.append([id, by, item]))
	var inputs := _inputs(4)
	race.karts[1].speed = 15.0
	_fire(items, inputs, 0, "drone")
	var shot: KartItemLogic.Shot = items.shots[0]
	assert_int(shot.target).is_equal(1)
	# It flies along the track, then hits its target.
	for i in roundi(8.0 / DT):
		items.step(DT, inputs)
		if not shot.alive:
			break
	assert_array(hits).is_equal([[1, 0, "drone"]])


func test_a_drone_from_the_leader_finds_nobody_and_fizzles() -> void:
	var race := _race([Vector2(300, 0), Vector2(100, 0)])
	var items := KartItemLogic.new(race, 1)
	var hits := []
	race.events.kart_hit.connect(func(id: int, by: int, item: String): hits.append([id, by, item]))
	_fire(items, _inputs(2), 0, "drone")
	_run(items, _inputs(2), KartItemLogic.DRONE_LIFE_SEC + 0.5)
	assert_array(hits).is_empty()
	assert_int(items.live_shots()).is_equal(0)


func test_goo_is_dropped_behind_and_spins_out_who_drives_through() -> void:
	var race := _race([Vector2(100, 0), Vector2(80, 0)])
	var items := KartItemLogic.new(race, 1)
	var hits := []
	race.events.kart_hit.connect(func(id: int, by: int, item: String): hits.append([id, by, item]))
	var inputs := _inputs(2)
	_fire(items, inputs, 0, "goo")
	assert_int(items.goos.size()).is_equal(1)
	var goo: KartItemLogic.Goo = items.goos[0]
	assert_float(race.track.delta(race.karts[0].s, goo.s)).is_less(-1.5)
	# The owner sitting on it a moment later is fine.
	_run(items, inputs, 0.5)
	assert_array(hits).is_empty()
	# A kart following drives through it.
	var k: KartState = race.karts[1]
	k.speed = 18.0
	for i in 120:
		_place(race, k, k.s + k.speed * DT, 0.0)
		items.step(DT, inputs)
	assert_array(hits).is_equal([[1, 0, "goo"]])
	assert_float(k.spin_time).is_greater(0.0)
	assert_int(items.live_goos()).is_equal(0)


func test_the_magnet_pulls_toward_the_kart_ahead_with_a_full_draft() -> void:
	var race := _race([Vector2(100, 1.5), Vector2(130, -1.5)])
	var items := KartItemLogic.new(race, 1)
	var inputs := _inputs(2)
	var k: KartState = race.karts[0]
	k.speed = 18.0
	race.karts[1].speed = 18.0
	_fire(items, inputs, 0, "magnet")
	assert_float(items.magnet_time[0]).is_greater(0.0)
	assert_int(items.magnet_target[0]).is_equal(1)
	_run(items, inputs, 1.0)
	assert_float(k.draft).is_equal(1.0)
	assert_float(k.speed).is_greater(18.5)
	assert_float(absf(k.d - race.karts[1].d)).is_less(3.0 - 0.5)
	_run(items, inputs, KartItemLogic.MAGNET_SEC)
	assert_float(items.magnet_time[0]).is_equal(0.0)


# --- Policy (bots and Auto items) ---

func test_auto_items_fire_the_riders_item_through_the_bot_policy() -> void:
	var race := _race([Vector2(100, 0), Vector2(115, 0)])
	var items := KartItemLogic.new(race, 1)
	var used := []
	race.events.item_used.connect(func(id: int, item: String): used.append([id, item]))
	items.give(0, "puck")
	_run(items, _inputs(2), 4.0)
	assert_array(used).is_empty()  # Auto items off: it waits for the tap
	items.auto_rider = true
	_run(items, _inputs(2), 4.0)
	assert_array(used).is_equal([[0, "puck"]])


func test_the_policy_aims_the_puck_and_keeps_the_shield_for_a_threat() -> void:
	var race := _race([Vector2(100, 0), Vector2(200, 0)])
	var items := KartItemLogic.new(race, 1)
	items.give(0, "puck")
	_run(items, _inputs(2), 2.0)
	# Nobody in range ahead: hold it for now.
	assert_bool(items.wants_use(0, 1.0)).is_false()
	_place(race, race.karts[1], 120.0, 0.3)
	assert_bool(items.wants_use(0, 1.0)).is_true()
