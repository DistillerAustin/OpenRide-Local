extends GdUnitTestSuite
## Kart Race's presentation (#43, Task E1): the HUD lays out at 1920x1080 with the framework HUD
## in its Kart Race skin and every kart widget at its longest text, with nothing overlapping or
## off screen; the skin's layout keys are opt-in and clear; a real touch on the item button uses
## the item and a touch elsewhere doesn't; the results board and the podium run with no input
## and advance on time; every effect preset renders cleanly; the music style renders; the
## audio's pure rules (stems, tempo, engine pitch) hold.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const Dsp := preload("res://audio/Dsp.gd")
const KartRaceScript := preload("res://games/kart_race/KartRace.gd")
const SCREEN := Rect2(0, 0, 1920, 1080)
const SEGMENT := {"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 300,
	"end_mode": "game", "seed": 7, "effort": true,
	"params": {"ftp_watts": 150, "bot_pcts": [0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75], "drift_resistance": 40}}
const DT := 1.0 / 60.0

var _rider := ""
var _saved_plan := {}


func before_test() -> void:
	_rider = "test%d" % Time.get_ticks_usec()
	_saved_plan = Session.plan
	Session.plan = {"rider_id": _rider}


func after_test() -> void:
	GameOptions.forget_rider(_rider)
	Session.plan = _saved_plan


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


# --- Layout ---

func _leaves(root: Node, out: Array[Control]) -> void:
	for child in root.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Control:
			var c := child as Control
			if c.name == "ReservedRight":
				continue  # the empty spacer that keeps the item button's corner free
			var is_leaf := c is Label or c is Button or (c.get_child_count() == 0 and c.size.x > 0.0 and c.size.y > 0.0)
			if is_leaf and c is Label and (c as Label).text.is_empty():
				is_leaf = false
			if is_leaf:
				out.append(c)
				continue
		_leaves(child, out)


func _hud_with_kart_hud() -> Array:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	var info := GameInfo.new()
	info.id = "kart_race"
	info.tracker_mode = "lean_stand"
	hud.setup(info, {"index": 0, "duration_sec": 3600})
	hud.set_skin(KartHud.hud_skin())
	hud.score.set_value("99999")
	var kh: KartHud = auto_free(KartHud.new())
	add_child(kh)
	var track := KartTrackModel.new(Fixtures.meadow())
	kh.setup(KartRoster.lineup("raccoon", 8), track)
	kh.set_gameplay_visible(true, false)
	return [hud, kh, track]


## A control's rect on the screen: a baked widget's (KartBaked) is in its own viewport, offset by
## the bake's place on screen.
func _screen_rect(c: Control) -> Rect2:
	var rect := c.get_global_rect()
	var bake := c.get_viewport().get_parent()
	if bake is KartBaked:
		rect.position += (bake as KartBaked).get_global_rect().position
	return rect


func test_the_kart_hud_lays_out_without_overlaps_at_its_longest() -> void:
	var parts := _hud_with_kart_hud()
	var hud: Hud = parts[0]
	var kh: KartHud = parts[1]
	var track: KartTrackModel = parts[2]
	Effort.begin_segment(true)
	# Worst-case contents.
	var race := KartRaceLogic.new()
	var racers := []
	for r in KartRoster.lineup("raccoon", 8):
		racers.append({"racer_id": r.id, "weight": r.weight})
	race.setup(track, racers, 5)
	race.phase = KartRaceLogic.Phase.RACING
	race.time = 3599.999
	var k: KartState = race.karts[0]
	k.place = 8
	k.lap = 5
	k.item = "magnet"
	k.drift_dir = 1
	k.drift_charge = 3.0
	k.drift_tier = 3
	k.knob_boosting = true
	kh.status.set_state(8, 8, 5, 5, "FINAL RACE")
	kh.ride_strip.refresh(188, 1888, 100, true, 1.5)
	kh.update(race, 0.1)
	await get_tree().create_timer(0.7).timeout  # the position pop settles
	await _settle()
	var leaves: Array[Control] = []
	_leaves(hud, leaves)
	_leaves(kh, leaves)
	assert_int(leaves.size()).is_greater(20)
	for c in leaves:
		var rect := _screen_rect(c)
		var bake := c.get_viewport().get_parent()
		if bake is KartBaked:
			var area := Rect2(Vector2.ZERO, Vector2((bake as KartBaked).viewport.size))
			assert_bool(area.encloses(c.get_global_rect().grow(-0.5))).override_failure_message("%s is cut off by its bake" % c.get_path()).is_true()
		assert_bool(SCREEN.encloses(rect.grow(-0.5))).override_failure_message("%s %s is off screen" % [c.get_path(), rect]).is_true()
	for i in leaves.size():
		for j in range(i + 1, leaves.size()):
			var a := _screen_rect(leaves[i]).grow(-0.5)
			var b := _screen_rect(leaves[j]).grow(-0.5)
			if leaves[i].is_ancestor_of(leaves[j]) or leaves[j].is_ancestor_of(leaves[i]):
				continue
			assert_bool(a.intersects(b)).override_failure_message("%s %s overlaps %s %s" % [
				leaves[i].get_path(), a, leaves[j].get_path(), b]).is_false()
	# The framework's touch targets stay full size and reachable; the item button is big and in
	# the top-right corner.
	for b: Button in [hud.pause_button, hud.end_button, hud.recalibrate_button]:
		assert_bool(b.is_visible_in_tree()).is_true()
		assert_float(b.size.y).is_greater_equal(HudTheme.BUTTON_HEIGHT * 0.8 - 0.5)
	var item := kh.item_button.get_global_rect()
	assert_float(item.size.x).is_greater_equal(240.0)
	assert_bool(item.get_center().x > SCREEN.size.x * 0.8 and item.get_center().y < SCREEN.size.y * 0.3).is_true()
	assert_bool(hud.ride_panel.visible).is_false()
	# The slow widgets are baked (one draw call each), and their bakes don't overlap either.
	for w: Control in [kh.status, kh.racer_list, kh.ride_strip]:
		assert_object(w.get_viewport().get_parent()).is_instanceof(KartBaked)
	Effort.begin_segment(false)


func test_the_skin_layout_keys_are_opt_in_and_clear() -> void:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	await _settle()
	var value: Label = hud.score._value
	var size_before := value.get_theme_font_size("font_size")
	var bar_children := hud.top_bar.get_child_count()
	hud.set_skin({"ride_panel": false, "clock_value_size": HudTheme.MEDIUM, "reserve_right": 260.0})
	assert_bool(hud.ride_panel.visible).is_false()
	assert_int(value.get_theme_font_size("font_size")).is_equal(HudTheme.MEDIUM)
	assert_int(hud.top_bar.get_child_count()).is_equal(bar_children + 1)
	await _settle()
	assert_float(hud.end_button.get_global_rect().end.x).is_less_equal(1920.0 - 40.0 - 260.0 + 0.5)
	hud.clear_skin()
	await _settle()
	assert_bool(hud.ride_panel.visible).is_true()
	assert_int(value.get_theme_font_size("font_size")).is_equal(size_before)
	assert_int(hud.top_bar.get_child_count()).is_equal(bar_children)


# --- Touch ---

func _game(seg := SEGMENT) -> Game:
	var game: Game = auto_free(load("res://games/kart_race/KartRace.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game)
	game.prepare(seg)
	game.start()
	return game


## A finger at `at` (canvas coordinates, 1920x1080), through the root viewport like the bike.
func _touch(canvas_at: Vector2) -> void:
	var at := canvas_at
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


func test_a_touch_on_the_item_button_uses_the_item_and_elsewhere_does_not() -> void:
	var game := _game()
	# Through the countdown, so the race HUD shows.
	var frames := 0
	while game.get("flow") != KartRaceScript.Flow.RACING and frames < 60 * 10:
		game._on_frame(DT)
		frames += 1
	var kh: KartHud = game.get("_kart_hud")
	kh.set_gameplay_visible(true, false)
	await _settle()
	var button := kh.item_button.get_global_rect()
	# (Input is handled at once; the checks read the edge before the game's next tick takes it.)
	# Elsewhere: the road, and the button's square corner outside its circle.
	for at in [Vector2(960, 700), button.position + Vector2(8, 8)]:
		_touch(at)
		assert_bool(game._read_rider().use_item).override_failure_message("a touch at %s used the item" % at).is_false()
	# On the button: the next input carries the item edge, once.
	_touch(button.get_center())
	assert_bool(game._read_rider().use_item).is_true()
	assert_bool(game._read_rider().use_item).is_false()


func test_a_tap_fires_the_item_the_roulette_landed_and_its_icon_matches() -> void:
	# The whole path: a pod starts the roulette; a tap mid-roulette does nothing; once the item
	# lands the button shows its icon, and a tap fires it through KartItemLogic (the Turbo Can:
	# one boost_started).
	var game := _game()
	var frames := 0
	while game.get("flow") != KartRaceScript.Flow.RACING and frames < 60 * 10:
		game._on_frame(DT)
		frames += 1
	var kh: KartHud = game.get("_kart_hud")
	kh.set_gameplay_visible(true, false)
	var race: KartRaceLogic = game.get("race")
	var items: KartItemLogic = game.get("items")
	var k: KartState = race.karts[KartRaceLogic.RIDER]
	var used := []
	var boosts := []
	race.events.item_used.connect(func(id: int, item: String): used.append([id, item]))
	race.events.boost_started.connect(func(id: int, kind: String, _tier: int):
		if id == KartRaceLogic.RIDER and kind == "item":
			boosts.append(kind))
	items.pods.clear()
	items.add_pod(k.s, k.d)
	game._on_frame(KartRaceScript.TICK)  # one logic tick
	assert_float(k.roulette_time).is_greater(0.0)
	items._pending[KartRaceLogic.RIDER] = "turbo"
	await _settle()
	var button := kh.item_button.get_global_rect()
	_touch(button.get_center())
	game._on_frame(KartRaceScript.TICK)
	assert_array(used).is_empty()
	while k.roulette_time > 0.0:
		game._on_frame(DT)
	assert_str(k.item).is_equal("turbo")
	assert_str(KartItemIcons.kind(k.item)).is_equal(k.item)
	await get_tree().create_timer(float(KartItemButton.DEBOUNCE_MS) / 1000.0 + 0.05).timeout
	_touch(button.get_center())
	for i in 120:
		game._on_frame(DT)
	assert_array(used).is_equal([[KartRaceLogic.RIDER, "turbo"]])
	assert_array(boosts).has_size(1)


func test_a_kart_at_the_lens_is_hidden_until_clear() -> void:
	var game := _game()
	var frames := 0
	while game.get("flow") != KartRaceScript.Flow.RACING and frames < 60 * 10:
		game._on_frame(DT)
		frames += 1
	var race: KartRaceLogic = game.get("race")
	var views: Array = game.get("views")
	var cam: KartChaseCamera = game.get("camera")
	var bot: KartState = race.karts[1]
	bot.pos = cam.global_position + Vector3.DOWN * 1.0
	game._sync_views(0.0)
	assert_bool(views[1].visible).is_false()
	assert_bool(views[KartRaceLogic.RIDER].visible).is_true()
	bot.pos = race.karts[KartRaceLogic.RIDER].pos + race.karts[KartRaceLogic.RIDER].forward() * 10.0
	game._sync_views(0.0)
	assert_bool(views[1].visible).is_true()


func test_a_new_track_redraws_the_minimap_with_the_same_lineup() -> void:
	var kh: KartHud = auto_free(KartHud.new())
	add_child(kh)
	kh.setup(KartRoster.lineup("raccoon", 8), KartTrackModel.new(Fixtures.meadow()))
	var before: PackedVector2Array = kh.minimap._pts.duplicate()
	kh.set_track(KartTrackModel.new(Fixtures.oval(300.0, 30.0, 6.0)))
	assert_bool(kh.minimap._pts == before).is_false()
	# The game hands every race's track to the HUD.
	var game := _game()
	var kh2: KartHud = game.get("_kart_hud")
	assert_object(kh2._map_track).is_same(game.get("track"))


func test_the_hud_icons_cover_every_item_id() -> void:
	for item in KartItemLogic.ITEMS:
		assert_str(KartItemIcons.kind(item)).is_equal(item)
	assert_array(KartItemIcons.KINDS).contains_exactly_in_any_order(KartItemLogic.ITEMS)


func test_the_drift_meter_uses_the_physics_tiers() -> void:
	var meter: KartDriftMeter = auto_free(KartDriftMeter.new())
	assert_array(meter.tiers).is_equal(KartPhysics.TIER_SEC)


# --- Flow screens ---

func test_the_results_and_podium_run_without_input_and_advance_on_time() -> void:
	var seg := SEGMENT.duplicate(true)
	var game := _game(seg)
	var inp := KartInput.new()
	inp.power_w = 320.0
	inp.cadence = 90.0
	game.set("test_input", inp)
	var race: KartRaceLogic = game.get("race")
	race.laps = 1
	assert_bool(bool(game.get("current").is_final)).is_true()
	var frames := 0
	while game.get("flow") != KartRaceScript.Flow.RESULTS and frames < 60 * 300:
		game._on_frame(DT)
		frames += 1
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.RESULTS)
	var board: KartRaceBoard = game.get("_board")
	assert_str(board.mode).is_equal("results")
	assert_bool(board.visible).is_true()
	var start: float = game.sim_time
	while game.get("flow") == KartRaceScript.Flow.RESULTS and frames < 60 * 400:
		game._on_frame(DT)
		frames += 1
	assert_float(game.sim_time - start).is_equal_approx(KartRaceScript.RESULTS_SEC, 0.1)
	assert_int(game.get("flow")).is_equal(KartRaceScript.Flow.PODIUM)
	assert_str(board.mode).is_equal("podium")
	start = game.sim_time
	while not game.has_ended() and frames < 60 * 500:
		game._on_frame(DT)
		frames += 1
	assert_bool(game.has_ended()).is_true()
	assert_float(game.sim_time - start).is_equal_approx(KartRaceScript.PODIUM_SEC, 0.1)


func test_the_board_counts_down_to_what_comes_next() -> void:
	var board: KartRaceBoard = auto_free(KartRaceBoard.new())
	add_child(board)
	var rows := []
	for i in 8:
		rows.append({"name": "Racer %d" % i, "detail": "+%d" % i, "total": "%d pts" % i, "time": "+1.000", "you": i == 2})
	board.show_board("Victory!", rows, "Grand Prix · Race 1", 8.0, "Next race")
	assert_bool(board.visible).is_true()
	board._process(3.0)
	assert_str(board._pill_label.text).ends_with("5")
	board.show_podium("Champion!", rows, "Final standings", 6.0, "Ride summary")
	assert_str(board.mode).is_equal("podium")
	board._process(6.5)
	assert_float(board.seconds_left()).is_less_equal(0.0)


func test_the_board_bakes_its_rows_title_and_pill() -> void:
	var board: KartRaceBoard = auto_free(KartRaceBoard.new())
	add_child(board)
	var rows := []
	for i in 8:
		rows.append({"name": "Racer %d" % i, "detail": "+%d" % i, "total": "%d pts" % i, "time": "+1.000", "you": i == 2})
	board.show_board("Victory!", rows, "Grand Prix · Race 1", 8.0, "Next race")
	var baked := board._content.get_children().filter(func(c): return c is KartBaked and not c.is_queued_for_deletion())
	assert_int(baked.size()).is_equal(8)
	assert_object(board._title.get_parent()).is_instanceof(SubViewport)
	assert_object(board._pill_box.get_parent()).is_instanceof(SubViewport)
	board.show_podium("Champion!", rows, "Final standings", 6.0, "Ride summary")
	baked = board._content.get_children().filter(func(c): return c is KartBaked and not c.is_queued_for_deletion())
	assert_int(baked.size()).is_equal(8 + 3)  # the standings and the three blocks



func test_the_board_renders_one_bake_a_frame() -> void:
	var board: KartRaceBoard = auto_free(KartRaceBoard.new())
	add_child(board)
	var rows := []
	for i in 8:
		rows.append({"name": "Racer %d" % i, "detail": "+%d" % i, "total": "%d pts" % i, "time": "+1.000", "you": i == 2})
	board.show_board("Victory!", rows, "Grand Prix · Race 1", 8.0, "Next race")
	var bakes := _bakes(board)
	assert_int(bakes.size()).is_equal(8 + 3)
	var before := _renders(bakes)
	assert_int(before).is_equal(0)  # nothing renders until its turn
	for f in 30:
		await get_tree().process_frame
		var now := _renders(bakes)
		assert_int(now - before).override_failure_message("frame %d rendered %d bakes" % [f, now - before]).is_less_equal(1)
		before = now
	# Every bake has had its turn.
	for b: KartBaked in bakes:
		assert_int(b.renders).override_failure_message("%s never rendered" % b.name).is_greater(0)
	assert_int(board.bakes.waiting()).is_equal(0)


func test_bake_queue_is_first_come_first_served() -> void:
	var q := KartBakeQueue.new()
	var a: Node = auto_free(Node.new())
	var b: Node = auto_free(Node.new())
	add_child(a)
	add_child(b)
	# b asks first; a, earlier in the tree, must wait its turn.
	assert_bool(q.grant(b)).is_true()
	assert_bool(q.grant(a)).is_false()
	await get_tree().process_frame
	assert_bool(q.grant(b)).is_false()  # a is ahead now
	assert_bool(q.grant(a)).is_true()
	await get_tree().process_frame
	assert_bool(q.grant(b)).is_true()


func _bakes(n: Node) -> Array:
	var out := []
	if n is KartBaked and not n.is_queued_for_deletion():
		out.append(n)
	for c in n.get_children():
		out.append_array(_bakes(c))
	return out


func _renders(bakes: Array) -> int:
	var total := 0
	for b: KartBaked in bakes:
		total += b.renders
	return total

# --- Audio ---

func test_every_kart_effect_renders_a_clean_sound() -> void:
	for sound in KartSfx.names():
		var p := KartSfx.preset(sound)
		var wav := SfxSynth.render(p)
		var n := Dsp.frames(wav)
		assert_int(n).override_failure_message("%s length %d" % [sound, n]).is_between(
			int(p.duration() * Dsp.SR) - 4, int(p.duration() * Dsp.SR) + 4)
		var peak := 0.0
		var max_step := 0.0
		for i in n:
			peak = maxf(peak, absf(Dsp.sample(wav, i)))
			if i > 0:
				max_step = maxf(max_step, absf(Dsp.sample(wav, i) - Dsp.sample(wav, i - 1)))
		assert_float(peak).override_failure_message("%s peak %.3f" % [sound, peak]).is_between(0.05, 0.99)
		if p.loop:
			assert_int(wav.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
			var seam := absf(Dsp.sample(wav, 0) - Dsp.sample(wav, n - 1))
			assert_float(seam).override_failure_message(sound + " clicks at the loop").is_less_equal(max_step * 1.1 + 0.001)
		else:
			assert_float(absf(Dsp.sample(wav, 0))).override_failure_message(sound + " starts with a click").is_less(0.002)
			assert_float(absf(Dsp.sample(wav, n - 1))).override_failure_message(sound + " ends with a click").is_less(0.002)
	# Registered, they play by name.
	KartSfx.register()
	for sound in KartSfx.names():
		assert_object(SfxSynth.stream(sound)).override_failure_message("no stream for " + sound).is_not_null()


func test_the_kart_music_style_renders_its_stems_and_final_lap_variation() -> void:
	var was := MusicGen.cache_enabled
	MusicGen.cache_enabled = false
	assert_object(MusicGen.style("kart_circuit")).is_not_null()
	var normal := MusicGen.generate({"style": KartAudio.STYLE, "tempo_bpm": 85.0, "seed": 3})
	var final_style := KartAudio.STYLE.duplicate(true)
	final_style.merge(KartAudio.FINAL_LAP, true)
	final_style["bars"] = 4
	var final := MusicGen.generate({"style": final_style, "tempo_bpm": 85.0, "seed": 3})
	MusicGen.cache_enabled = was
	assert_array(normal.keys()).contains_exactly_in_any_order(MusicGen.STEMS)
	var n := Dsp.frames(normal.drums)
	for stem in MusicGen.STEMS:
		assert_int(Dsp.frames(normal[stem])).is_equal(n)
	# One and a half beats per pedal stroke: 85 rpm plays at 127.5 bpm.
	assert_int(n).is_equal(MusicGen.loop_samples(127.5))
	assert_array(final.keys()).contains_exactly_in_any_order(MusicGen.STEMS)
	# The variation is lifted: another tune from the same seed.
	var base_tune := MusicGen.compose(MusicGen.resolve_style(KartAudio.STYLE), 3)
	var final_tune := MusicGen.compose(MusicGen.resolve_style(final_style), 3)
	assert_bool(base_tune.lead == final_tune.lead).is_false()
	# Every stem has a gate the intensity crosses.
	for stem in ["harmony", "lead"]:
		assert_bool(KartAudio.STYLE.stem_gates.has(stem)).is_true()


func test_the_audio_rules() -> void:
	# Stems: drums and bass on the grid, more in the race, everything on the final lap.
	assert_float(KartAudio.intensity_for("COUNTDOWN", 8, false, false)).is_less(KartAudio.STYLE.stem_gates.harmony)
	assert_float(KartAudio.intensity_for("RACING", 6, false, false)).is_between(KartAudio.STYLE.stem_gates.harmony, KartAudio.STYLE.stem_gates.lead - 0.01)
	assert_float(KartAudio.intensity_for("RACING", 2, false, false)).is_greater_equal(KartAudio.STYLE.stem_gates.lead)
	assert_float(KartAudio.intensity_for("RACING", 7, true, false)).is_greater_equal(KartAudio.STYLE.stem_gates.lead)
	assert_float(KartAudio.intensity_for("RACING", 8, false, true)).is_equal(1.0)
	# Tempo follows cadence in steps, within the range.
	assert_float(KartAudio.tempo_cadence_for(87.0)).is_equal(85.0)
	assert_float(KartAudio.tempo_cadence_for(40.0)).is_equal(KartAudio.CADENCE_RANGE.x)
	assert_float(KartAudio.tempo_cadence_for(140.0)).is_equal(KartAudio.CADENCE_RANGE.y)
	# The engine climbs with speed.
	var last := 0.0
	for v in [0.0, 5.0, 10.0, 20.0, 30.0]:
		var p := KartAudio.engine_pitch(v, false)
		assert_float(p).is_greater(last)
		last = p


# --- Drawing ---

func test_kart_draw_builds_valid_triangles() -> void:
	var d := KartDraw.new()
	d.disc(Vector2(50, 50), 20.0, Color.WHITE)
	d.ring(Vector2(50, 50), 20.0, 30.0, Color.RED, Color(-1, 0, 0), 0.0, PI)
	d.rect(Rect2(0, 0, 100, 40), Color.BLUE, 12.0)
	d.polygon(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 3), Vector2(10, 10), Vector2(0, 10)]), Color.GREEN)
	assert_int(d.indices.size() % 3).is_equal(0)
	assert_int(d.points.size()).is_equal(d.colors.size())
	for i in d.indices:
		assert_int(i).is_between(0, d.points.size() - 1)
	for id in ["turbo_can", "bumper_puck", "seeker_drone", "goo_puddle", "shield_bubble", "draft_magnet"]:
		assert_str(KartItemIcons.kind(id)).is_not_empty()
	assert_str(KartItemIcons.kind("mystery")).is_empty()
