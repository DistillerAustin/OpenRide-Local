extends GdUnitTestSuite
## The hub's picture cards (spec §7.2, plan C1): each picture is inset evenly from its card's
## outline and masked to a rounded rect of radius R - inset (concentric with the outline, so no
## square corner pokes past it: the rider's bug with the old picker's track cards); no card
## leans; a pick re-renders only the two cards it changes.

const THUMB := "res://games/kart_race/ui/tracks/meadow_ring.png"

var _queue: BakeQueue


func before_test() -> void:
	_queue = BakeQueue.new()
	_queue.per_frame = 4


func _spec(columns: int, count := 4, image := THUMB) -> Dictionary:
	var choices: Array = []
	var cards: Array = []
	for i in count:
		choices.append("c%d" % i)
		cards.append({"value": "c%d" % i, "title": "Card %d" % i, "subtitle": "1,148 m", "image": image})
	return {"key": "k", "label": "Starting track", "choices": choices, "default": "c0", "kind": "cards",
		"columns": columns, "cards": cards, "rider_badge": true}


func _grid(spec: Dictionary, width := 1040.0) -> OptionCards:
	var cards := OptionCards.new(spec, str(spec.default), width, _queue, null, "Bartholomew Montgomery-Smythe")
	add_child(cards)
	auto_free(cards)
	return cards


func _settle(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame


func test_the_mask_radius_is_the_card_radius_less_the_inset_at_every_size() -> void:
	for columns in range(1, GameInfo.COLUMNS_MAX + 1):
		var cards := _grid(_spec(columns))
		await _settle(2)
		for v in cards.cards:
			var mat: ShaderMaterial = cards.picture(v).material
			assert_object(mat.shader).is_equal(load(HubArt.MASK_SHADER))
			assert_float(float(mat.get_shader_parameter("radius"))).is_equal(float(HubTheme.CARD_RADIUS - HubTheme.PICTURE_INSET))
			assert_vector(mat.get_shader_parameter("rect_size")).is_equal(cards.picture(v).size)
		remove_child(cards)


func test_a_wide_picture_is_inset_evenly_and_never_leans() -> void:
	for columns in [2, 4, 5]:
		var cards := _grid(_spec(columns))
		await _settle()
		for v in cards.cards:
			var card: HubCard = cards.cards[v]
			var panel := card.content as PanelContainer
			var pic := cards.picture(v)
			var outer := panel.get_global_rect()
			var inner := pic.get_global_rect()
			var inset := HubTheme.PICTURE_INSET
			assert_float(inner.position.x - outer.position.x).override_failure_message("left inset at %d columns" % columns).is_equal_approx(inset, 0.6)
			assert_float(outer.end.x - inner.end.x).override_failure_message("right inset at %d columns" % columns).is_equal_approx(inset, 0.6)
			assert_float(inner.position.y - outer.position.y).override_failure_message("top inset at %d columns" % columns).is_equal_approx(inset, 0.6)
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			assert_vector(style.skew).is_equal(Vector2.ZERO)
			assert_int(style.corner_radius_top_left).is_equal(HubTheme.CARD_RADIUS)
			assert_bool(card.content.size.x <= card.size.x + 0.5 and card.content.size.y <= card.size.y + 0.5) \
				.override_failure_message("%s overflows its bake at %d columns: %s > %s" % [v, columns, card.content.size, card.size]).is_true()
		remove_child(cards)


func test_a_narrow_picture_is_fitted_and_centred() -> void:
	var portrait := "res://games/kart_race/ui/portraits/fox.png"
	if not ResourceLoader.exists(portrait):
		portrait = "res://icon.svg"
	var cards := _grid(_spec(4, 2, portrait))
	await _settle()
	var pic := cards.picture("c0")
	var slot := OptionCards.slot_size(cards.card_size.x)
	assert_float(pic.size.y).is_equal(slot.y)
	assert_float(pic.position.x * 2.0 + pic.size.x).is_equal_approx(slot.x, 1.0)


func test_the_chosen_card_wears_the_riders_name() -> void:
	var cards := _grid(_spec(4))
	await _settle()
	assert_bool(cards.badge("c0").visible).is_true()
	assert_bool(cards.badge("c1").visible).is_false()
	var label := cards.badge("c0").get_child(0) as Label
	assert_str(label.text).is_equal("Bartholomew…")
	assert_int(label.get_theme_font_size("font_size")).is_greater_equal(HudTheme.SMALL)


func test_a_pick_re_renders_only_the_two_cards_it_changes() -> void:
	var cards := _grid(_spec(4))
	await _settle(20)
	var before := {}
	for v in cards.cards:
		before[v] = (cards.cards[v] as HubCard).bake.renders
	var seen: Array = []
	cards.changed.connect(func(k: String, v: String): seen.append([k, v]))
	cards.cards["c2"].hit.pressed.emit()
	await _settle(20)
	assert_array(seen).is_equal([["k", "c2"]])
	assert_bool(cards.badge("c2").visible).is_true()
	assert_bool(cards.badge("c0").visible).is_false()
	var changed: Array = []
	for v in cards.cards:
		if (cards.cards[v] as HubCard).bake.renders != before[v]:
			changed.append(v)
	changed.sort()
	assert_array(changed).is_equal(["c0", "c2"])
	cards.cards["c2"].hit.pressed.emit()  # the same card again: nothing changes
	assert_int(seen.size()).is_equal(1)


func test_the_home_cards_pictures_use_the_same_mat() -> void:
	var pic := HubArt.picture("kart_race", Vector2(314, 177), HubTheme.CARD_RADIUS - HubTheme.PICTURE_INSET)
	auto_free(pic)
	assert_float(float((pic.material as ShaderMaterial).get_shader_parameter("radius"))).is_equal(16.0)
