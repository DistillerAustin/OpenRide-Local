extends GdUnitTestSuite
## The kart and track picker (#43, rider request 2026-10-19): Kart Race's first state once
## gameplay starts. It preselects the rider's last kart and track (GameOptions, per rider),
## starts by itself, restarts its count on a tap, sets the Grand Prix's first track, puts the
## rider's name on the chosen kart, moves and scores nothing, and keeps big targets far from End.

const KartRaceScript := preload("res://games/kart_race/KartRace.gd")
const SEGMENT := {"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 1200,
	"end_mode": "game", "seed": 7, "effort": true,
	"params": {"ftp_watts": 150, "bot_pcts": [0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75], "drift_resistance": 40}}
const DT := 1.0 / 60.0

var _rider := ""
var _saved_plan := {}


func before_test() -> void:
	_rider = "picker%d" % Time.get_ticks_usec()
	_saved_plan = Session.plan
	Session.plan = {"rider_id": _rider, "rider_name": "Ed"}


func after_test() -> void:
	GameOptions.forget_rider(_rider)
	Session.plan = _saved_plan


func _info() -> GameInfo:
	var g: Game = KartRaceScript.new()
	var info := g.info()
	g.free()
	return info


## A game prepared and started with the picker on (headless runs skip it by default).
func _game(seg := SEGMENT, power := 200.0) -> Game:
	var game: Game = auto_free(load("res://games/kart_race/KartRace.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game.hud)
	game.hud.set_skin(KartHud.hud_skin())
	add_child(game)
	game.prepare(seg)
	var inp := KartInput.new()
	inp.power_w = power
	inp.cadence = 90.0
	game.set("test_input", inp)
	game.set("picker_enabled", true)
	game.start()
	return game


func _frames(game: Game, n: int) -> void:
	for i in n:
		game._on_frame(DT)


func _picker(game: Game) -> KartPicker:
	return game.get("_picker")


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


func _touch(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		get_tree().root.push_input(touch, true)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		get_tree().root.push_input(click, true)


func test_it_opens_first_with_the_riders_last_kart_and_track() -> void:
	GameOptions.set_value(_info(), "driver", "otter", _rider)
	GameOptions.set_value(_info(), "track", "frost_pass", _rider)
	var game := _game()
	var picker := _picker(game)
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.PICK)
	assert_bool(picker.visible).is_true()
	assert_bool(picker.picking).is_true()
	assert_str(picker.racer_id).is_equal("otter")
	assert_str(picker.track_id).is_equal("frost_pass")
	# The remembered track's grid is already built behind it.
	assert_str(game.get("current").track_id).is_equal("frost_pass")
	assert_int(picker.kart_buttons.size()).is_equal(8)
	assert_int(picker.track_buttons.size()).is_equal(4)
	assert_int(picker.seconds_left()).is_equal(int(KartPicker.AUTO_SEC))
	# Both are options on the pause screen too.
	assert_bool(_info().option_spec("track").is_empty()).is_false()
	assert_array(_info().validate()).is_empty()


func test_nothing_moves_or_scores_while_picking() -> void:
	Effort.begin_segment(true)
	Effort.set_live(true)
	var game := _game(SEGMENT, 400.0)
	var race: KartRaceLogic = game.get("race")
	var pos: Vector3 = race.karts[0].pos
	var bot: Vector3 = race.karts[1].pos
	_frames(game, 60 * 5)
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.PICK)
	assert_int(race.phase).is_equal(KartRaceLogic.Phase.GRID)
	assert_vector(race.karts[0].pos).is_equal(pos)
	assert_vector(race.karts[1].pos).is_equal(bot)
	assert_float(game.score()).is_equal(0.0)
	assert_float(game.get("sim_time")).is_greater(4.0)  # the session's clock runs: a warm-up
	assert_float(game.played_sec).is_equal(0.0)  # _on_frame directly; Game._process counts it live
	Effort.begin_segment(false)


func test_it_starts_by_itself_and_a_tap_restarts_the_count() -> void:
	var game := _game()
	var picker := _picker(game)
	_frames(game, roundi(12.0 / DT))
	assert_int(picker.seconds_left()).is_equal(8)
	picker.select_track("canyon_dash")
	assert_int(picker.seconds_left()).is_equal(int(KartPicker.AUTO_SEC))
	_frames(game, roundi(12.0 / DT))
	picker.select_racer("panda")
	assert_int(picker.seconds_left()).is_equal(int(KartPicker.AUTO_SEC))
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.PICK)
	_frames(game, roundi(KartPicker.AUTO_SEC / DT) + 6)
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.COUNTDOWN)
	assert_str(game.get("current").track_id).is_equal("canyon_dash")
	assert_str(game.get("lineup")[0].id).is_equal("panda")
	assert_bool(picker.visible).is_false()


func test_the_pick_is_remembered_per_rider() -> void:
	var game := _game()
	var picker := _picker(game)
	picker.select_racer("rabbit")
	picker.select_track("harbor_lights")
	# Remembered at the tap, before Start (the pause screen's options show it).
	assert_str(GameOptions.get_value(_info(), "driver", _rider)).is_equal("rabbit")
	assert_str(GameOptions.get_value(_info(), "track", _rider)).is_equal("harbor_lights")
	picker.start()
	_frames(game, 4)
	GameOptions.reload()
	assert_str(GameOptions.get_value(_info(), "driver", _rider)).is_equal("rabbit")
	assert_str(GameOptions.get_value(_info(), "track", _rider)).is_equal("harbor_lights")
	# Another rider's choices are their own.
	assert_str(GameOptions.get_value(_info(), "track", _rider + "_other")).is_equal(KartTracks.CUP[0])
	GameOptions.forget_rider(_rider + "_other")
	# The next session opens on them.
	var next := _game()
	assert_str(_picker(next).racer_id).is_equal("rabbit")
	assert_str(_picker(next).track_id).is_equal("harbor_lights")
	assert_str(next.get("current").track_id).is_equal("harbor_lights")


func test_the_grand_prix_starts_at_the_chosen_track_then_the_cup_order() -> void:
	assert_array(KartGrandPrix.cup_from(KartTracks.CUP, "harbor_lights")).is_equal(
		["harbor_lights", "frost_pass", "meadow_ring", "canyon_dash"])
	assert_array(KartGrandPrix.cup_from(KartTracks.CUP, "meadow_ring")).is_equal(KartTracks.CUP)
	assert_array(KartGrandPrix.cup_from(KartTracks.CUP, "nowhere")).is_equal(KartTracks.CUP)
	var game := _game()
	_picker(game).select_track("harbor_lights")
	_picker(game).start()
	_frames(game, 4)
	var gp: KartGrandPrix = game.get("gp")
	assert_array(gp.track_ids).is_equal(["harbor_lights", "frost_pass", "meadow_ring", "canyon_dash"])
	assert_str(game.get("current").track_id).is_equal("harbor_lights")
	assert_bool(game.get("current").reversed).is_false()
	assert_int(gp.races_run()).is_equal(0)
	assert_int(int(game.get("current").index)).is_equal(0)


func test_a_five_minute_ride_is_one_race_on_the_chosen_track() -> void:
	var seg := SEGMENT.duplicate(true)
	seg.duration_sec = 300
	var game := _game(seg)
	_picker(game).select_track("frost_pass")
	_picker(game).start()
	_frames(game, 4)
	var current: Dictionary = game.get("current")
	assert_str(current.track_id).is_equal("frost_pass")
	assert_bool(current.is_final).is_true()
	assert_int(int(current.laps)).is_between(1, KartGrandPrix.MAX_LAPS)


func test_the_last_race_is_sized_to_the_time_left_after_the_pick() -> void:
	# The picker's seconds come off the ride: the final race is sized to what's left after them.
	var seg := SEGMENT.duplicate(true)
	seg.duration_sec = 300
	var est: float = KartGrandPrix.estimate_lap_sec(KartTracks.average_length(), 150.0)
	var game := _game(seg)
	game.played_sec = 200.0  # a long dither on the picker (Game._process counts it live)
	_picker(game).start()
	_frames(game, 4)
	var current: Dictionary = game.get("current")
	assert_bool(current.is_final).is_true()
	assert_int(int(current.laps)).is_equal(clampi(roundi(100.0 / est), 1, KartGrandPrix.MAX_LAPS))


func test_the_chosen_kart_carries_the_riders_name() -> void:
	var game := _game()
	var picker := _picker(game)
	picker.select_racer("penguin")
	picker.start()
	_frames(game, 4)
	var lineup: Array = game.get("lineup")
	assert_str(lineup[0].id).is_equal("penguin")
	assert_str(lineup[0].name).is_equal("Ed")
	assert_str(lineup[0].species).is_equal("penguin")
	for r in lineup.slice(1):
		assert_str(r.name).is_equal(KartRoster.racer(r.id).name)
	assert_int(game.get("views").size()).is_equal(8)
	assert_str(picker.rider_name).is_equal("Ed")


func test_a_new_track_builds_behind_a_loading_card() -> void:
	var game := _game()
	var picker := _picker(game)
	assert_str(game.get("current").track_id).is_equal("meadow_ring")
	picker.select_track("canyon_dash")
	picker.start()
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.LOADING)
	assert_bool(picker.visible).is_true()
	_frames(game, 3)
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.COUNTDOWN)
	assert_str(game.get("current").track_id).is_equal("canyon_dash")
	assert_float(game.get("rebuild_ms")).is_greater(0.0)
	print("rebuild canyon_dash after the pick: %.0f ms" % game.get("rebuild_ms"))
	# The same track starts at once, with no rebuild.
	var same := _game()
	_picker(same).start()
	assert_int(same.get("flow")).is_equal(KartRaceScript.Flow.COUNTDOWN)
	assert_float(same.get("rebuild_ms")).is_equal(0.0)


func test_the_targets_are_huge_and_far_from_end() -> void:
	var game := _game()
	var picker := _picker(game)
	var hud: Hud = game.hud
	await _settle()
	var end := hud.end_button.get_global_rect()
	assert_bool(hud.end_button.is_visible_in_tree()).is_true()
	var targets := picker.targets()
	assert_int(targets.size()).is_equal(13)
	var screen := Rect2(0, 0, 1920, 1080)
	for t in targets:
		var rect: Rect2 = t.rect
		assert_float(minf(rect.size.x, rect.size.y)).override_failure_message("%s %s is small" % [t.id, rect]) \
			.is_greater_equal(KartPicker.MIN_TARGET)
		assert_bool(screen.encloses(rect)).is_true()
		# 120 px clear of End, every side.
		assert_bool(rect.grow(120.0).intersects(end)).override_failure_message("%s %s is near End %s" % [t.id, rect, end]) \
			.is_false()
		# Above the bottom band, where the camera strip goes.
		assert_float(rect.end.y).is_less_equal(950.0)
		for u in targets:
			if u != t:
				assert_bool(rect.intersects(u.rect)).is_false()
	var start: Rect2 = targets.back().rect
	assert_float(start.size.y).is_greater_equal(240.0)
	assert_float(start.size.x).is_greater_equal(500.0)
	# Nothing the picker draws is near End or under the framework's other buttons and clock.
	for b in picker.bakes:
		var drawn := b.get_global_rect().grow(-KartBaked.PAD)
		assert_bool(drawn.grow(120.0).intersects(end)) \
			.override_failure_message("%s %s is near End %s" % [b.name, drawn, end]).is_false()
		for c: Control in [hud.pause_button, hud.recalibrate_button, hud.clock_panel]:
			assert_bool(drawn.intersects(c.get_global_rect())) \
				.override_failure_message("%s %s is under %s %s" % [b.name, drawn, c.name, c.get_global_rect()]).is_false()


func test_real_touches_pick_and_never_reach_end() -> void:
	var game := _game()
	var picker := _picker(game)
	var hud: Hud = game.hud
	await _settle()
	var ends := [0]
	hud.end_pressed.connect(func(): ends[0] += 1)
	for id in ["bear", "frog"]:
		_touch((picker.kart_buttons[id] as Control).get_global_rect().get_center())
		assert_str(picker.racer_id).is_equal(id)
	for id in ["harbor_lights", "meadow_ring"]:
		_touch((picker.track_buttons[id] as Control).get_global_rect().get_center())
		assert_str(picker.track_id).is_equal(id)
	_touch(picker.start_button.get_global_rect().get_center())
	assert_bool(picker.picking).is_false()
	assert_int(ends[0]).is_equal(0)


func test_the_ui_is_baked_and_idle_between_changes() -> void:
	var game := _game()
	var picker := _picker(game)
	await _settle()
	assert_int(picker.bakes.size()).is_equal(5)
	for i in 30:
		await get_tree().process_frame
	var before := 0
	for b in picker.bakes:
		before += b.renders
		assert_bool(b.is_pending()).is_false()
	# A quiet second renders nothing (the count's text changes only on whole seconds).
	for i in 10:
		await get_tree().process_frame
	var after := 0
	for b in picker.bakes:
		after += b.renders
	assert_int(after).is_equal(before)
	# A tap re-renders the kart grid and the detail, nothing else.
	picker.select_racer("bear")
	for i in 6:
		await get_tree().process_frame
	assert_bool(picker.bakes[1].renders > 0 and picker.bakes[2].renders > 0).is_true()
	var tracks_before := picker.bakes[3].renders
	for i in 4:
		await get_tree().process_frame
	assert_int(picker.bakes[3].renders).is_equal(tracks_before)


func test_every_track_has_a_baked_thumbnail() -> void:
	for id in KartTracks.CUP:
		var tex := KartPicker.thumbnail(id)
		assert_object(tex).override_failure_message("no thumbnail for %s" % id).is_not_null()
		assert_int(tex.get_width()).is_less_equal(512)


func test_request_finish_on_the_picker_ends_cleanly() -> void:
	var game := _game()
	_frames(game, 30)
	game.request_finish()
	assert_bool(game.has_ended()).is_true()
	var result := game.finish()
	assert_int(int(result.stats.races)).is_equal(0)
