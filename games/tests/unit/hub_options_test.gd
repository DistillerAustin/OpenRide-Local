extends GdUnitTestSuite
## Game options in the hub (spec §7, plan C1): every game's hub options (`where` hub or both)
## appear on its screen, as cards, rows or under "More options"; a pick is saved per rider at
## once (GameOptions); the pause screen shows only `where` pause or both.

var local: Node
var hub: Node
var rider := ""


func before() -> void:
	HubPrefs.path = "user://hub_prefs_options_test.cfg"
	HubPrefs.reload()
	GameOptions.path = "user://game_options_hub_test.cfg"
	GameOptions.reload()


func after() -> void:
	HubPrefs.path = HubPrefs.DEFAULT_PATH
	HubPrefs.reload()
	GameOptions.path = GameOptions.DEFAULT_PATH
	GameOptions.reload()


func before_test() -> void:
	local = Session._local
	local.process_mode = Node.PROCESS_MODE_DISABLED
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.begin_visit()
	hub = get_tree().current_scene
	rider = HubPrefs.rider(hub.state)
	GameOptions.forget_rider(rider)
	await _settle()


func after_test() -> void:
	GameOptions.forget_rider(rider)
	local.hub.phase = ""
	Session.visit_id = ""
	Session.hub = {}
	Session.director.phase = SessionDirector.Phase.IDLE
	local.process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0


func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame


func _open(game_id: String) -> GameScreen:
	hub.nav.push(HubNav.GAME, {"game_id": game_id})
	await _settle()
	return hub.screen


func test_every_hub_option_appears_on_its_game_screen() -> void:
	for e in HubState.games(hub.state):
		var screen := await _open(str(e.id))
		var info := GameRegistry.info(str(e.id))
		var grouped: Array = []
		for o in info.hub_options():
			if GameInfo.option_kind(o) != "cards" and str(o.get("group", "")) != "":
				grouped.append(str(o.key))
				continue
			assert_bool(screen.option_controls.has(str(o.key))) \
				.override_failure_message("%s: option %s isn't on screen" % [e.id, o.key]).is_true()
			assert_bool((screen.option_controls[o.key] as Control).is_visible_in_tree()).is_true()
		assert_bool(screen.more_button != null).override_failure_message("%s: More options iff grouped" % e.id) \
			.is_equal(not grouped.is_empty())
		if not grouped.is_empty():
			screen.open_more()
			await _settle(2)
			for k in grouped:
				assert_bool(screen.option_controls.has(k)).override_failure_message("%s: %s not under More options" % [e.id, k]).is_true()
			assert_bool(screen.left.visible).is_false()
			screen.close_more()
		hub.nav.pop()
		await _settle(2)


func test_a_row_pick_is_saved_per_rider_at_once() -> void:
	var screen := await _open("safe_cracker")
	var info := GameRegistry.info("safe_cracker")
	var row: OptionRow = screen.option_controls["scene"]
	var before := GameOptions.get_value(info, "scene", rider)
	if row.segmented:
		row.segmented.pick(str(row.spec.choices[1]))
	else:
		row.cycle.pressed.emit()
	var now := GameOptions.get_value(info, "scene", rider)
	assert_str(now).is_not_equal(before)
	assert_str(GameOptions.get_value(info, "scene", rider + "x")).is_equal(before)
	hub.nav.pop()
	await _settle(2)
	screen = await _open("safe_cracker")
	assert_str((screen.option_controls["scene"] as OptionRow).value).is_equal(now)


func test_kart_race_shows_eight_kart_cards_and_four_track_cards() -> void:
	var screen := await _open("kart_race")
	var karts: OptionCards = screen.option_controls["driver"]
	var tracks: OptionCards = screen.option_controls["track"]
	assert_int(karts.cards.size()).is_equal(8)
	assert_int(tracks.cards.size()).is_equal(4)
	assert_int(karts.grid.columns).is_equal(4)
	for k in ["assist", "camera", "auto_items"]:  # secondary: under More options
		assert_bool(screen.option_controls.has(k)).is_false()
	assert_object(screen.more_button).is_not_null()
	# The chosen kart wears the rider's name; a tap saves the kart and moves the name.
	var info := GameRegistry.info("kart_race")
	var shown := HubTheme.short_name(str(hub.state.rider.name))
	assert_bool(karts.badge("fox").visible).is_true()
	assert_str((karts.badge("fox").get_child(0) as Label).text).is_equal(shown)
	karts.cards["penguin"].hit.pressed.emit()
	assert_str(GameOptions.get_value(info, "driver", rider)).is_equal("penguin")
	assert_bool(karts.badge("penguin").visible).is_true()
	assert_bool(karts.badge("fox").visible).is_false()
	tracks.cards["frost_pass"].hit.pressed.emit()
	assert_str(GameOptions.get_value(info, "track", rider)).is_equal("frost_pass")
	# Every track card's thumbnail is masked to the card's outline.
	for v in tracks.cards:
		var mat := tracks.picture(v).material as ShaderMaterial
		assert_float(float(mat.get_shader_parameter("radius"))).is_equal(float(HubTheme.CARD_RADIUS - HubTheme.PICTURE_INSET))
	screen.open_more()
	await _settle(2)
	for k in ["assist", "camera", "auto_items"]:
		assert_object((screen.option_controls[k] as OptionRow).segmented).is_not_null()


func test_the_pause_screen_shows_only_pause_options() -> void:
	var info := GameInfo.new()
	info.options = [
		{"key": "a", "label": "A", "choices": ["x", "y"], "default": "x", "where": "hub"},
		{"key": "b", "label": "B", "choices": ["x", "y"], "default": "x", "where": "pause"},
		{"key": "c", "label": "C", "choices": ["x", "y"], "default": "x"},
	]
	assert_array(info.hub_options().map(func(o): return o.key)).is_equal(["a", "c"])
	assert_array(info.pause_options().map(func(o): return o.key)).is_equal(["b", "c"])
	var pause := PauseOverlay.new()
	pause.set_options(info.options, func(_k): return "x")
	assert_object(pause._options_box.get_node_or_null("Option_a")).is_null()
	assert_object(pause._options_box.get_node_or_null("Option_b")).is_not_null()
	assert_object(pause._options_box.get_node_or_null("Option_c")).is_not_null()
	pause.free()


func test_a_card_falls_back_to_its_label() -> void:
	var spec := {"key": "k", "label": "K", "choices": ["a", "b"], "labels": ["Ay", "Bee"], "default": "a",
		"kind": "cards", "cards": [{"value": "a", "title": "Alpha", "subtitle": "first", "accent": Color.RED}]}
	assert_dict(GameInfo.card_for(spec, "a")).is_equal({"value": "a", "title": "Alpha", "subtitle": "first", "image": "", "accent": Color.RED})
	assert_dict(GameInfo.card_for(spec, "b")).is_equal({"value": "b", "title": "Bee", "subtitle": "", "image": "", "accent": null})
