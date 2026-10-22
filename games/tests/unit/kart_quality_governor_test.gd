extends GdUnitTestSuite
## Kart Race's adaptive quality (#43): KartQualityGovernor steps down one tier per 4 s window
## below 56 fps, at least 4 s apart, never below its floor and never back up; only racing frames
## count. The world, the effects and the view apply each tier, and a new session starts full.

const DT60 := 1.0 / 60.0
const DT50 := 1.0 / 50.0


## Feeds `seconds` of frames at `dt`; returns how many stepped.
func _run(g: KartQualityGovernor, seconds: float, dt: float, racing := true) -> int:
	var stepped := 0
	for i in roundi(seconds / dt):
		if g.sample(dt, racing):
			stepped += 1
	return stepped


func test_a_steady_60_never_steps() -> void:
	var g := KartQualityGovernor.new()
	assert_int(_run(g, 60.0, DT60)).is_equal(0)
	assert_int(g.tier).is_equal(0)
	assert_float(g.last_fps).is_equal_approx(60.0, 0.01)


func test_a_slow_window_steps_one_tier_after_4_s() -> void:
	var g := KartQualityGovernor.new()
	assert_int(_run(g, 3.9, DT50)).is_equal(0)
	assert_int(_run(g, 0.2, DT50)).is_equal(1)
	assert_int(g.tier).is_equal(1)
	assert_str(String(g.tier_name())).is_equal("fx")
	assert_float(g.steps[0].fps).is_equal_approx(50.0, 0.01)


func test_steps_are_at_least_4_s_apart_and_stop_at_the_floor() -> void:
	var g := KartQualityGovernor.new()
	var at := []
	var t := 0.0
	for i in roundi(60.0 / DT50):
		t += DT50
		if g.sample(DT50, true):
			at.append(t)
	assert_int(g.tier).is_equal(KartQualityGovernor.TIERS.size() - 1)
	assert_int(at.size()).is_equal(KartQualityGovernor.TIERS.size() - 1)
	for i in range(1, at.size()):
		assert_float(at[i] - at[i - 1]).is_greater_equal(KartQualityGovernor.WINDOW_SEC - 0.001)


func test_a_raised_floor_holds() -> void:
	var g := KartQualityGovernor.new()
	g.floor_tier = 2
	_run(g, 60.0, DT50)
	assert_int(g.tier).is_equal(2)


func test_it_never_steps_back_up() -> void:
	var g := KartQualityGovernor.new()
	_run(g, 4.1, DT50)
	assert_int(g.tier).is_equal(1)
	_run(g, 30.0, DT60)
	assert_int(g.tier).is_equal(1)


func test_only_racing_frames_count() -> void:
	var g := KartQualityGovernor.new()
	# Slow boards and countdowns don't step...
	assert_int(_run(g, 20.0, DT50, false)).is_equal(0)
	# ...and leaving the race drops a part-filled window.
	_run(g, 3.0, DT50)
	_run(g, 1.0, DT50, false)
	assert_int(_run(g, 3.0, DT50)).is_equal(0)
	assert_int(_run(g, 1.1, DT50)).is_equal(1)


func test_a_window_just_at_the_target_holds() -> void:
	var g := KartQualityGovernor.new()
	assert_int(_run(g, 8.0, 1.0 / 56.0)).is_equal(0)


func test_trims_accumulate_by_tier() -> void:
	var g := KartQualityGovernor.new()
	assert_bool(g.trims(&"foliage")).is_false()
	g.tier = 2
	assert_bool(g.trims(&"fx")).is_true()
	assert_bool(g.trims(&"foliage")).is_true()
	assert_bool(g.trims(&"crowd")).is_false()
	assert_bool(g.trims(&"full")).is_false()


func test_the_world_trims_foliage_and_crowd_and_keeps_them_across_tracks() -> void:
	var w: KartWorld = auto_free(KartWorld.new())
	add_child(w)
	w.build(KartTrackModel.new(KartTracks.build("meadow_ring")))
	var crowd: MultiMesh = (w.find_child("Crowd", true, false) as MultiMeshInstance3D).multimesh
	var cells := w.find_children("Foliage_*", "GeometryInstance3D", true, false)
	assert_int(cells.size()).is_greater(0)
	w.set_quality(KartWorld.CELL_RANGE_TRIMMED, KartWorld.CROWD_TRIMMED)
	for c: GeometryInstance3D in cells:
		assert_float(c.visibility_range_end).is_equal(KartWorld.CELL_RANGE_TRIMMED)
	assert_int(crowd.visible_instance_count).is_equal(roundi(crowd.instance_count * 0.5))
	# A new track keeps the trims.
	w.build(KartTrackModel.new(KartTracks.build("meadow_ring"), true))
	await get_tree().process_frame
	for c: GeometryInstance3D in w.find_children("Foliage_*", "GeometryInstance3D", true, false):
		if not c.is_queued_for_deletion():
			assert_float(c.visibility_range_end).is_equal(KartWorld.CELL_RANGE_TRIMMED)


func test_the_effects_cap_halves() -> void:
	var fx: KartFx = auto_free(KartFx.new())
	add_child(fx)
	fx.cap_share = 0.5
	for i in 400:
		fx._puff(Vector3.ZERO, Vector3.ZERO, 5.0, Vector2.ONE, Color.WHITE)
		fx._spark(Vector3.ZERO, Vector3.ZERO, 5.0, Vector2.ONE, Color.WHITE)
	assert_int(fx._pn).is_equal(KartFx.PUFFS / 2)
	assert_int(fx._sn).is_equal(KartFx.SPARKS / 2)


func test_the_game_applies_each_tier_and_a_new_session_starts_full() -> void:
	var game: Game = auto_free(load("res://games/kart_race/KartRace.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game)
	var seg := {"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 600,
		"end_mode": "game", "seed": 7, "effort": true, "params": {"ftp_watts": 150}}
	game.prepare(seg)
	var q: KartQualityGovernor = game.get("quality")
	var view: SubViewport = game.get("_view")
	var full_size := view.size
	# The game's governor stops at the effects trim (the others saved nothing on the tablet).
	assert_int(q.floor_tier).is_equal(1)
	q.tier = KartQualityGovernor.TIERS.size() - 1  # the tuning file can still force the last tier
	game._apply_quality()
	var world: KartWorld = game.get("world")
	assert_float(world.foliage_range).is_equal(KartWorld.CELL_RANGE_TRIMMED)
	assert_float(world.crowd_share).is_equal(KartWorld.CROWD_TRIMMED)
	assert_float((game.get("_fx") as KartFx).cap_share).is_equal(0.5)
	assert_int(view.size.x).is_equal(roundi(1920 * 0.58))
	assert_int(view.size.x).is_less(full_size.x)
	# The next session: a new governor, everything back.
	game.prepare(seg)
	assert_int((game.get("quality") as KartQualityGovernor).tier).is_equal(0)
	assert_int(view.size.x).is_equal(full_size.x)
	assert_float((game.get("world") as KartWorld).foliage_range).is_equal(KartWorld.CELL_RANGE)
